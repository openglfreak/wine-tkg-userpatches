This repo contains a set of userpatches for [Wine-TkG](https://github.com/Frogging-Family/wine-tkg-git/tree/master/wine-tkg-git).  
The rename.sh script is licensed under the [MPL 2.0](https://www.mozilla.org/en-US/MPL/2.0/).  
The patches are intended to keep their original license, however I'm taking the liberty of rebasing the patches to work on Wine-TkG.

To add a new patch/-set:

* Pick the first free patchset number (ignoring patchsets 9990-9999).
* Save the patches with the file names prefixed with `ps<number>-`,  
  where &lt;number&gt; is the four-digit patchset number.
* Run the rename.sh script, answer Y if it asks to rename one of your patches.

All patches must have the file extension `.mypatch`.  
All patches must have exactly one Subject, except for those from the patchsets 9990-9999.  
If a patch doesn't have a Subject, it must be added to patchset 9999 with a descriptive name.  
If a patch has multiple Subjects, it must be split.

Note that these rules only apply when you want to make pull requests to this repo.
