/*
 Copyright (c) 2009 Kristofer Karlsson <kristofer.karlsson@gmail.com>

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
 */

package se.krka.kahlua.integration.expose.caller;

import java.lang.invoke.MethodHandle;
import java.lang.invoke.MethodHandles;
import java.lang.invoke.MethodType;
import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.lang.reflect.Modifier;

import se.krka.kahlua.integration.expose.ReturnValues;
import se.krka.kahlua.integration.processor.DescriptorUtil;

public class MethodCaller extends AbstractCaller {

    public static boolean DEBUG = false;

    private final Method method;
    private final Object owner;
    private final boolean hasSelf;
    private final boolean hasReturnValue;
    private boolean isStatic = false;
    private String methodName;
    private Class<?>[] methodParameters;
    private MethodType methodType;
    private MethodHandle methodHandle;
    private MethodHandles.Lookup lookup = MethodHandles.lookup();
    private Object[] parameterCache;

    public MethodCaller(Method method, Object owner, boolean hasSelf) {
        super(method.getParameterTypes());
        this.method = method;
        this.owner = owner;
        this.hasSelf = hasSelf;
        method.setAccessible(true);
        // New Method invocation.
        methodName = method.getName();
        methodParameters = method.getParameterTypes();
        isStatic = Modifier.isStatic(method.getModifiers());
        Class classMethodDecl = owner != null ? owner.getClass() : method.getDeclaringClass();
        if (DEBUG) {
            System.out.print("Registering MethodCaller: " + classMethodDecl.getSimpleName() + "."
                    + methodName + (methodParameters.length > 0 ? " ::" : ""));
            for (int index = 0; index < methodParameters.length; index++) {
                Class param = methodParameters[index];
                System.out.print(" (" + index + "): (" + param.getSimpleName() + ")");
            }
            System.out.print("\n");
        }
        methodType = MethodType.methodType(method.getReturnType(), methodParameters);
        try {
            methodHandle = lookup.unreflect(method);
        } catch (IllegalAccessException e) {
            e.printStackTrace();
        }

        if (!isStatic && methodParameters.length > 0) {
            parameterCache = new Object[methodParameters.length + 1];
        }

        // End.
        hasReturnValue = !method.getReturnType().equals(Void.TYPE);
        if (hasReturnValue && needsMultipleReturnValues()) {
            throw new IllegalArgumentException("Must have a void return type if first argument is a ReturnValues: got: " + method.getReturnType());
        }
    }

    @Override
    public void call(Object self, ReturnValues rv, Object[] params) throws IllegalArgumentException, IllegalAccessException, InvocationTargetException {
        if (!hasSelf) {
            self = owner;
        }
        // Old Method invocation.
        // Object ret = method.invoke(self, params);
        //
        // New Method invocation.
        Object ret = null;
        try {
            if (isStatic) {
                if (params.length == 0) {
                    ret = methodHandle.invoke();
                } else {
                    ret = methodHandle.invokeWithArguments(params);
                }
            } else {
                if (params.length == 0) {
                    ret = methodHandle.invoke(self);
                } else {
                    parameterCache[0] = self;
                    System.arraycopy(params, 0, parameterCache, 1, parameterCache.length - 1);
                    ret = methodHandle.invokeWithArguments(parameterCache);
                }
            }
        } catch (Throwable throwable) {
            System.out.println("Method: " + methodName + " static = " + isStatic);
            System.out.println("Arguments: ");
            for (int index = 0; index < params.length; index++) {
                Object param = params[index];
                if (param != null) {
                    System.out.println("\t(" + index + "): (" + param.getClass().getSimpleName() + ") = " + param.toString());
                } else {
                    System.out.println("\t(" + index + "): (NULL)");
                }
            }
            throwable.printStackTrace();
        } finally {
            // Clear the argument cache if one exists.
            if (parameterCache != null && parameterCache.length > 0) {
                for (int index = 0; index < parameterCache.length; index++) {
                    parameterCache[index] = null;
                }
            }
        }
        // End.
        if (hasReturnValue) {
            rv.push(ret);
        }
    }

    @Override
    public boolean hasSelf() {
        return hasSelf;
    }

    @Override
    public String getDescriptor() {
        return DescriptorUtil.getDescriptor(method);
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (o == null || getClass() != o.getClass()) return false;

        MethodCaller that = (MethodCaller) o;

        if (!method.equals(that.method)) return false;
        if (owner != null ? !owner.equals(that.owner) : that.owner != null) return false;

        return true;
    }

    @Override
    public int hashCode() {
        int result = method.hashCode();
        result = 31 * result + (owner != null ? owner.hashCode() : 0);
        return result;
    }
}
