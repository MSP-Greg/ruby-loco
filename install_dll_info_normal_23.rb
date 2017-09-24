# DLLInfo contains all the information for which dlls are needed for which build.
# Information is stored in arrays. All files in FILES constants are contained
# in mingw##/bin directory.
#
# Each arrays contains arrays with three elements:
#
# 0 - lower integer bound for Ruby version ('a.b.c' int = 10000a + 100b + c)
#
# 1 - upper integer bound for Ruby version
#
# 2 - array of required files
#
# #### Summary of required dlls
# ```
# x64-msvcrt-ruby240.dll => libgmp-10.dll
#
#     msvcrt-ruby240.dll => libgmp-10.dll => libgcc_s_dw2-1.dll => libwinpthread-1.dll
#
#
# dbm.so      => libgdbm_compat-4.dll => libgdbm-4.dll
#
# fiddle.so   => libffi-6.dll
#
# gdbm.so     => libgdbm-4.dll        => libintl-8.dll    => libiconv-2.dll
#
# psych.so    => libyaml-0-2.dll
#
# readline.so => libreadline7.dll     => libtermcap-0.dll
#             => libhistory7.dll  ?
#
# zlib.so     => zlib1.dll
# ```
#
module InstallDLLInfo

  DIRS_ALL = [
    [     0,  20400, 'lib/engines'    ],
    [ 20400, 999999, 'lib/engines-1_1']
  ]

  # Files needed by both 32 and 64 bit builds.
  FILES_ALL = [
    [     0, 999999, %w[
      libffi-6.dll
      libgdbm-4.dll
      libgdbm_compat-4.dll
      libgmp-10.dll
      libhistory7.dll
      libiconv-2.dll
      libintl-8.dll
      libreadline7.dll
      libtermcap-0.dll
      libyaml-0-2.dll
      zlib1.dll
    ]]
  ]

  # Files needed for 32 bit builds.
  FILES_32 = [
    [     0, 999999, %w[
      libgcc_s_dw2-1.dll
      libwinpthread-1.dll
    ]],

    [     0,  20400, %w[
      libeay32.dll
      ssleay32.dll
    ]],
    [ 20400, 999999, %w[
      libcrypto-1_1.dll
      libssl-1_1.dll
    ]]
  ]

  # Files needed for 64 bit builds.
  # swap between OpenSSL files, 2.3 
  FILES_64 = [
    [     0,  20400, %w[
      libeay32.dll
      ssleay32.dll
      libgcc_s_seh-1.dll
      libwinpthread-1.dll
    ]],
    [ 20400, 999999, %w[
      libcrypto-1_1-x64.dll
      libssl-1_1-x64.dll
    ]]
  ]
end