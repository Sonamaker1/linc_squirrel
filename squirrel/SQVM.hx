package squirrel;

import bindingGen.Pointer;

@:native("SQVM")
@:include('linc_squirrel.h')
extern private class SQVM {}

#if cpp
typedef HSQUIRRELVM = cpp.Pointer<SQVM>;
#else
typedef HSQUIRRELVM = Pointer<SQVM>;
#end
