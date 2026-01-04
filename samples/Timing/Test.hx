import haxe.Exception;
import squirrel.SQ;
import squirrel.SQstd;
import squirrel.SQVM;

enum abstract RT_Type(String) from String to String {
    var RT_NULL        = "o";
    var RT_INTEGER     = "i";
    var RT_FLOAT       = "f";
    var RT_NUMBER      = "n"; // (_RT_FLOAT | _RT_INTEGER)
    var RT_STRING      = "s";
    var RT_TABLE       = "t";
    var RT_ARRAY       = "a";
    var RT_USERDATA    = "u";
    var RT_CLOSURE     = "c"; // (_RT_CLOSURE | _RT_NATIVECLOSURE)
    var RT_BOOL        = "b";
    var RT_GENERATOR   = "g";
    var RT_USERPOINTER = "p";
    var RT_THREAD      = "v";
    var RT_INSTANCE    = "x";
    var RT_CLASS       = "y";
    var RT_WEAKREF     = "r";
}

enum AcceptedType {
    TFloat(f: Float);
    TInt(i: Int);
    TBool(b: Bool);
    TNullDynamic(d: Null<Dynamic>); // Or a more specific type
    TClass(s: String);
}

class Test {
    inline static function buildTypecheck(arr:Array<RT_Type>):String {
        arr.unshift(RT_TABLE); //Required
        return arr.join("");
    }
      
    static function main() {
        callFunction();
    }

    static function getElapsed(){
        
    }

    static var object:Map<String,Dynamic> = new Map();

    static function callFunction() {
        var v:HSQUIRRELVM = SQ.open(1024); //creates a VM with initial stack size 1024
        function register(name:String, inputs:Array<RT_Type>, callback:Dynamic){
            SQ.register(v, name, callback, inputs.length+1, buildTypecheck(inputs) );
        }

        function resolveAndPushType(x:Dynamic){ 
            var ret = 0;   
            switch (Type.typeof(x)) {
                case TClass(String):
                    SQ.pushstring(v, cast(x,String), -1); ret = 1;
                case TNull:
                    SQ.pushnull(v); ret = 1;
                case TBool:
                    SQ.pushbool(v,cast(x,Bool)); ret = 1;
                case TInt:
                    SQ.pushinteger(v, cast(x,Int)); ret = 1;
                case TFloat:
                    SQ.pushfloat(v, cast(x,Float)); ret = 1;
                case TFunction:
                    trace("myValue is a Function");
                case TObject:
                    trace("myValue is a generic Object");
                case TClass(c):
                    trace('myValue is an instance of class: ${Type.getClassName(c)}');
                case TEnum(e):
                    trace('myValue is an instance of enum: ${Type.getEnumName(e)}');
                case _: // Default case for any other type
                    trace("myValue has an unknown type");
            }
            return ret;
        }

        function callSQFunction(name:String, values:Array<Dynamic>){
            if(name.length>1){
                SQ.pushroottable(v);
                SQ.pushstring(v, name, -1);
                SQ.get(v,-2); //get the function from the root table
                SQ.pushroottable(v); //’this’ (function environment object)
                var valid = 0;
                var invalidCounter = 0;
                for (y in values) {
                    var validCheck = resolveAndPushType(y);
                    valid += validCheck;
                    if(validCheck < 1){
                        throw new haxe.Exception('Invalid ${Type.typeof(y)} input to callSQFunction at argument ${valid+1}');
                    }
                }
                if(valid == values.length){
                    SQ.call(v, values.length+1, false, true);
                }
                SQ.pop(v, 2); //pops the roottable and the function
            }
        }
        
        function makeFunctions(){
            register("callback", [RT_STRING], (x) ->{trace(x);});
            register("sleep", [RT_FLOAT], (x) ->{Sys.sleep(x);});
            register("time", [], () ->{haxe.Timer.stamp();});
            register("getElapsed", [], () ->{getElapsed();});
            register("setElapsed", [], () ->{getElapsed();});
            register("getUpdateLoop", [], () ->{getElapsed();});

            register("ReflectPushStack", [RT_STRING,RT_STRING,RT_STRING], (key, objectname, field) ->{
                try{
                    object.set(key,Reflect.getProperty(object.get(objectname),field));
                }
                catch(err){
                    trace(err);
                }
            });
            register("ReflectFields", [RT_STRING], (objectname) ->{
                try{
                    var objList:Array<String> = objectname.split(".");
                    var lastObject:Dynamic = object.get(objList.shift());
                    for(x in objList){
                        lastObject = Reflect.getProperty(lastObject, x);
                    }
                    trace(Reflect.fields(lastObject));
                }
                catch(err){
                    trace(err);
                }
            });
        }

        SQ.pushroottable(v); //push the root table (where the globals of the script will be stored)
        SQstd.seterrorhandlers(v); //registers the default error handlers
        SQ.setprintfunc(v); //sets the print function
        SQ.init_callbacks(v); // unofficial API
        
        makeFunctions();

        SQstd.dofile(v, "main.nut", false, true); // load compile and run script
        callSQFunction("update", [1.0001]);
        SQ.close(v);
        trace("Closed Squirrel VM\n");  
    }
}
