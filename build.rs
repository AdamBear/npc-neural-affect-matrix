fn main() {
    // On Windows MSVC, force the cc crate to use dynamic CRT
    // This affects dependencies like esaxx-rs that use the cc crate
    #[cfg(all(target_os = "windows", target_env = "msvc"))]
    {
        // Force cc crate to use dynamic CRT in all build modes
        // Set CRT_STATIC=0 to tell cc crate to use /MD instead of /MT
        std::env::set_var("CRT_STATIC", "0");

        // Also set CFLAGS and CXXFLAGS to override any hardcoded settings
        let current_cflags = std::env::var("CFLAGS").unwrap_or_default();
        let current_cxxflags = std::env::var("CXXFLAGS").unwrap_or_default();

        // Add /MD flag to force dynamic CRT
        std::env::set_var("CFLAGS", format!("{} /MD", current_cflags));
        std::env::set_var("CXXFLAGS", format!("{} /MD", current_cxxflags));

        println!("cargo:warning=Forcing dynamic CRT (/MD) for all C/C++ dependencies");
    }
}
