// License: public domain
module generators;

import std.traits, std.typetuple, core.thread;
import std.conv : text;

void yield(alias var)(typeof(var) value)
{
    static assert(__traits(isOut, var), "Yield works only with OUT arguments");
    auto fiber = Fiber.getThis();
    if (!fiber)
        return; // do nothing
    var = value;
    Fiber.yield();
}

private template Generator(T...)
    if (staticLength!T >= 1 && isCallable!(T[0]))
{
    alias T[0] F;
    alias ParameterTypeTuple!F AllParams;
    alias ParameterStorageClassTuple!F Stc;
    
    template StripOutParams(size_t i)
    {
        static if (i < AllParams.length)
        {
            static if (Stc[i] != ParameterStorageClass.OUT)
                alias TypeTuple!(AllParams[i], StripOutParams!(i + 1)) StripOutParams;
            else
                alias StripOutParams!(i + 1) StripOutParams;
        }
        else
            alias TypeTuple!() StripOutParams;
    }
    
    alias StripOutParams!0 Params;

    static assert(AllParams.length - Params.length == 1, "Generator function must have exactly one OUT argument");
    static assert(is(ReturnType!F == void), F.stringof ~ ", does not return void");
    static assert(Params.length == T.length - 1, text("Generator ", F.stringof, " expects ", Params.length,
                                                      " argument(s), not ", T.length - 1));
    
    template OutParamIndex(size_t i)
    {
        static if (i < AllParams.length)
        {
            static if (Stc[i] == ParameterStorageClass.OUT)
                enum OutParamIndex = i;
            else
                enum OutParamIndex = OutParamIndex!(i + 1);
        }
        else
            enum OutParamIndex = -1;
    }
    
    enum outIndex = OutParamIndex!0;
    
    alias AllParams[outIndex] ValueType;
    
    class Generator : Fiber
    {
        F fn;
        AllParams allParams;
        
        this(F fn, Params params)
        {
            super(&fiberMain);
            this.fn = fn;
            
            foreach (i, param; allParams)
            {
                static if (i < outIndex)
                    allParams[i] = params[i];
                else static if (i > outIndex)
                    allParams[i] = params[i - 1];
            }
            
            call();
        }
        
        void fiberMain()
        {
            fn(allParams);
        }
        
        @property bool empty()
        {
            return state == State.TERM;
        }
        
        void popFront()
        {
            call();
        }
        
        @property pure nothrow ValueType front()
        {
            return allParams[outIndex];
        }
    }
}

auto generator(T...)(T t)
{
    return new Generator!T.Generator(t);
}
