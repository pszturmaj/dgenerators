module generators;

import std.traits, core.thread;

void yield(alias var)(typeof(var) value)
{
    static assert(__traits(isOut, var), "Yield works only with OUT arguments");
    Fiber fiber = Fiber.getThis();
    if (!fiber)
        return; // do nothing
    var = value;
    Fiber.yield();
}

private template _generator(T...)
    if (staticLength!T >= 1 && isCallable!(T[0]))
{
    alias T[0] F;
    alias ParameterTypeTuple!F AllParams;
    alias ParameterStorageClassTuple!F Stc;
    
    import std.typetuple;
    
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
    static assert(is(ReturnType!F == void), (&F).stringof ~ ", does not return void");
    static assert(is(Params == T[1..$]), "Arguments do not match");
    
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
        
        bool empty()
        {
            return state == State.TERM;
        }
        
        void popFront()
        {
            call();
        }
        
        pure nothrow ValueType front()
        {
            return allParams[outIndex];
        }
    }
}

auto generator(T...)(T t)
{
    return new _generator!T.Generator(t);
}
