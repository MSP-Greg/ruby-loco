### 2017-05-10

* Added patch for [`lib/mkmf.rb`](https://github.com/MSP-Greg/ruby-loco/blob/master/patches/lib-mkmf.rb.patch), seems to reliably run make with -j3.  Passes test-all.

* Added two encoding related lines at the end of [`pkg_set_env.cmd`](https://github.com/MSP-Greg/ruby-loco/blob/master/pkg_set_env.cmd.sample).  Seems to improve test-all results if these are both set to 'filesystem' encoding.

* Added patches for [`ruby/test_process.rb`](https://github.com/MSP-Greg/ruby-loco/blob/master/patches/test-ruby-test_process.patch) & [`ruby/test_rubyoptions.rb`](https://github.com/MSP-Greg/ruby-loco/blob/master/patches/test-ruby-test_rubyoptions.patch).  These remove three test-all failures.

### 2017-05-06

* Update PKGBUILD for 2017-05-06_58576 - removed ncurses and after-update, which seemed to be causing duplicate tasks with make all.

### 2017-05-03

* Update PKGBUILD for 2017-05-03 58552

### 2017-05-02

* PKGBUILD
  * Added jobs variable
  * Adjusted make command to run correctly