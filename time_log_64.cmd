@ruby time_log.rb

@ren %R_NAME%-%R_VERS%-1-x86_64-build.log      %R_NAME%-build.log
@ren %R_NAME%-%R_VERS%-1-x86_64-package.log    %R_NAME%-package.log
@ren %R_NAME%-%R_VERS%-1-x86_64-prepare.log    %R_NAME%-prepare.log
@ren %R_NAME%-%R_VERS%-1-x86_64-test-all.log   %R_NAME%-test-all.log
@ren %R_NAME%-%R_VERS%-1-x86_64-test-basic.log %R_NAME%-test-basic.log
@ren %R_NAME%-%R_VERS%-1-x86_64-test-btest.log %R_NAME%-test-btest.log
@ren %R_NAME%-%R_VERS%-1-x86_64-test-mspec.log %R_NAME%-test-mspec.log
@ren %R_NAME%-%R_VERS%-1-x86_64-test-spec.log  %R_NAME%-test-spec.log

@%MSYS2_DIR%/usr/bin/sed -i -r '/^\[[-]/d'   ./%R_NAME%-test-mspec.log
@%MSYS2_DIR%/usr/bin/sed -i -r '/^\[[-]/d'   ./%R_NAME%-test-spec.log

@%MSYS2_DIR%/usr/bin/sed -i -r '/^\.{30,}/d' ./%R_NAME%-test-mspec.log
@%MSYS2_DIR%/usr/bin/sed -i -r '/^\.{30,}/d' ./%R_NAME%-test-spec.log
