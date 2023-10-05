
// If you add your own plugin to this bundle - don't forget mention it here and add to `.github/workflows/build-and-upload.yml`
// This file - scratch for SourceMod 1.11 compiler features when passing multiple sources. Required only for CI.

#if defined _MATERIALADMIN
    #include "materialadmin.sp"
#endif

#if defined _MATERIALADMIN_ADMINMENU
    #include "ma_adminmenu.sp"
#endif

#if defined _MATERIALADMIN_BASECOMMS
    #include "ma_basecomm.sp"
#endif

#if defined _MATERIALADMIN_BASEVOTES
    #include "ma_basevotes.sp"
#endif

#if defined _MATERIALADMIN_CHECKER
    #include "ma_checker.sp"
#endif

#if defined _MATERIALADMIN_NOVOICE
    #include "ma_novoice.sp"
#endif