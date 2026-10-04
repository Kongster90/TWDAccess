using System.Runtime.InteropServices;

namespace TWDAccess;

/// <summary>P/Invoke declarations for the subset of the Prism C API we use (prism.h, v0.18.x).</summary>
internal static class Prism
{
    private const string Dll = "prism.dll";

    public const int PRISM_OK = 0;
    public const int PRISM_ERROR_NOT_IMPLEMENTED = 3;
    public const int PRISM_ERROR_ALREADY_INITIALIZED = 15;

    [DllImport(Dll, CallingConvention = CallingConvention.Cdecl)]
    public static extern IntPtr prism_init(IntPtr cfg);

    [DllImport(Dll, CallingConvention = CallingConvention.Cdecl)]
    public static extern void prism_shutdown(IntPtr ctx);

    [DllImport(Dll, CallingConvention = CallingConvention.Cdecl)]
    public static extern IntPtr prism_registry_acquire_best(IntPtr ctx);

    [DllImport(Dll, CallingConvention = CallingConvention.Cdecl)]
    public static extern IntPtr prism_registry_acquire(IntPtr ctx, ulong id);

    [DllImport(Dll, CallingConvention = CallingConvention.Cdecl)]
    public static extern ulong prism_registry_id(IntPtr ctx, [MarshalAs(UnmanagedType.LPUTF8Str)] string name);

    [DllImport(Dll, CallingConvention = CallingConvention.Cdecl)]
    public static extern UIntPtr prism_registry_count(IntPtr ctx);

    [DllImport(Dll, CallingConvention = CallingConvention.Cdecl)]
    public static extern ulong prism_registry_id_at(IntPtr ctx, UIntPtr index);

    [DllImport(Dll, CallingConvention = CallingConvention.Cdecl)]
    public static extern IntPtr prism_registry_name(IntPtr ctx, ulong id);

    [DllImport(Dll, CallingConvention = CallingConvention.Cdecl)]
    public static extern void prism_backend_free(IntPtr backend);

    [DllImport(Dll, CallingConvention = CallingConvention.Cdecl)]
    public static extern IntPtr prism_backend_name(IntPtr backend);

    [DllImport(Dll, CallingConvention = CallingConvention.Cdecl)]
    public static extern int prism_backend_initialize(IntPtr backend);

    [DllImport(Dll, CallingConvention = CallingConvention.Cdecl)]
    public static extern int prism_backend_output(IntPtr backend, [MarshalAs(UnmanagedType.LPUTF8Str)] string text,
        [MarshalAs(UnmanagedType.U1)] bool interrupt);

    [DllImport(Dll, CallingConvention = CallingConvention.Cdecl)]
    public static extern int prism_backend_speak(IntPtr backend, [MarshalAs(UnmanagedType.LPUTF8Str)] string text,
        [MarshalAs(UnmanagedType.U1)] bool interrupt);

    [DllImport(Dll, CallingConvention = CallingConvention.Cdecl)]
    public static extern int prism_backend_stop(IntPtr backend);

    [DllImport(Dll, CallingConvention = CallingConvention.Cdecl)]
    public static extern IntPtr prism_error_string(int error);

    [DllImport(Dll, CallingConvention = CallingConvention.Cdecl)]
    public static extern IntPtr prism_version_string();

    public static string Str(IntPtr p) => p == IntPtr.Zero ? "" : Marshal.PtrToStringUTF8(p) ?? "";

    public static string ErrorString(int error) => Str(prism_error_string(error));
}
