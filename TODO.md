## TODO List

### Patch and DLL List Assembly

Currently, dll list assembly works on what one might call a 'positive assembly',
as the list starts empty, then items are added to it.

I would prefer that the patches list works in a negative manner, in that all patches
will be contained in the patches, 64, and 32 dirs, and then patches will be removed
as required.  This will allow users to add patches for testing without having to change code.

Also, I intend to keep the 'starting underscore' removes a patch concept.

Another desire is that dlls for, and patches of, gems (default and bundled) and std-lib
items be  based on the gem/std-lib version, as opposed to the ruby version or svn
number.  As an example, I believe the OpenSSL extension vers 2+ works with OpenSSL 1.1.0,
but earlier versions require OpenSSL 1.0.2.  Rather than get tangled up in Ruby
versions, it would be easiest to handle it via the gem / std-lib version number.
