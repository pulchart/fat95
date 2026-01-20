A quick guide to using the supplied dosC file with Amithlon
+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
Last updated: 21st September 2002.


DISCLAIMER:
I am not responsible if you make some change to the
supplied files which causes damage or other problems to
your computer; if you have little idea what you are doing,
it would be a good idea to ask for help from someone!

That said, I am not aware of any way you could cause damage
by just changing the supplied tooltype parameters.


PURPOSE:
To allow an Amithlon user to use a modern version of the
FAT95 filingsystem, rather than the old v2.17 that is built
into it.

It is not possible for Amithlon to auto-mount all DOS
partitions using the new FAT95 version, but at least you
will be using a more robust (newer) version of FAT95!


THE QUICK GUIDE:
1.This first step is not always essential, but highly
recommended.  Download & install FAT95 v3.04 or greater.
Then check the disk for errors by setting the comment of a
file on the drive to just "!scandisk" (without "quotes").
If there are no errors, then proceed, otherwise fix the
errors first (typically using Windows).

2.You should know the unit(s) & device(s) on which your FAT
partition(s) exist.  In simple PC setups, you may be able
to identify them from HDToolbox by looking for harddrives
which are not "installed" (cannot be partitioned yet).
Beware that (accidentally) modifying a FAT harddrive from
AmigaOS is not advised!

3.Remove (or ;comment out) the S:startup-sequence line
which resembles:
         Setconfig >NIL: dosmount "<all>"

4.For the file "S:amithlon_patches/patch1_msdos.o", either
delete it or move it to another folder (e.g.  into a
subdirectory you make called "unused").

5.Reboot.  You should now NOT be able to see any mounted
FAT volumes.  So you now know that any FAT volumes that are
mounted later are using the version of FAT95 that you
install (rather than Amithlon's outdated version).

6.Copy the dosC file (with icon!) to the
"SYS:Devs/DOSDrivers/" folder.  You may want/need to use a
name other than "dosC" for the file (e.g.  dosD or dosE).

7.Edit the tooltypes of the file's icon to the correct unit
& device information; you may be lucky that these do not
need changing.

8.Reboot.  If the FAT volume does not appear, then check
the unit & device information is correct.  If they are,
then try altering the dostype (best using the FAT95 docs,
but reminder information is given at the bottom of the
tooltypes) by trial and error.  Either way, repeat this
step until success.

9.As a final check that you have correctly mounted the
partition, repeat the check for errors on the disk as you
did in step 1.  New errors probably indicate something is
wrong - do NOT use the mounted partition from AmigaOS until
this is fixed.  If you did NOT do step 1, then you cannot
know if any errors are due to your new mount file or not.

10.If you have more FAT volumes to mount, go back to step 5.


FURTHER HELP:
First look in the FAT95 documentation.  If that is not
enough, you might try asking on the Amithlon Yahoo mailing
list (see http://groups.yahoo.com/group/amithlon/ ).


Also, you might like to try the MountDos v1.2 program
available from the Aminet.  I have supplied an example icon
which will work on *typical* PCs running Amithlon.

If MountDos is supplied with the correct device & unit
information (similar to step 7), then the tool can display
all partitions found, show suitable mountlist entries (which
you could try copying into the supplied dosC textfile if you
are CAREFUL), and optionally auto-mount all found DOS
partitions using FAT95.  I do not recommend automounting if
you need to rely on the "dosC" style device name; MountDos
uses a different convention.


Good luck!

Chris Handley
