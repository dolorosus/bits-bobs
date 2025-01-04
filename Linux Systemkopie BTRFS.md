# Systemkopie Linux auf BTRFS Partition:

## Das System von einer Live-DVD booten

den alten Datenträger bereitstellen und auf dem neuen Datenträger die Zielpartitionen entsprechend einrichten. Hier ein Beispiel:
. 
```
Modell: Samsung SSD 990 PRO 2TB (nvme)  
Festplatte  /dev/nvme0n1:  2000GB  
Sektorgröße (logisch/physisch): 512B/512B  
Partitionstabelle: gpt  
Disk-Flags:    
  
Nummer  Anfang  Ende    Größe   Dateisystem   Name  Flags  
       17,4kB  1049kB  1031kB  Freier Platz  
1      1049kB  211MB   210MB   fat32               boot, esp  
2      211MB   269GB   268GB   btrfs  
3      269GB   952GB   683GB   btrfs  
4      952GB   1896GB  944GB  
       1896GB  2000GB  105GB   Freier Platz
```

Wenn gleichzeitig noch Windows verwendet werden soll, muss eine MSR Partition angelegt werden. 
```
2      106MB   123MB   16,8MB                Microsoft reserved partition  msftres, no_automount
```

Die Flags werden entsprechend https://www.gnu.org/software/parted/manual/html_node/set.html gesetzt.

## Kopie vorbereiten
anschließend die Inhalte von Root,Home,... auf die neue Platte kopieren.

In diesem Beispiel wurde die alte Partition auf `/mnt/src` eingehängt, die neue nach `/mnt/dst`
### Mountpoints erstellen
```sh
# root werden
la@lanb109:~$ sudo -i

# Erstelle Mountpoints für die alte und neue Partition
#
root@lanb109:~# mkdir /mnt/{src,dst}
```

### Partitionen mounten

```sh
# einhängen der Partitionen. Die Quelle als nur-lesen einhängen
#
root@lanb109:~# mount /dev/sdb9 -o ro /mnt/src
root@lanb109:~# mount /dev/nvme0n1p2  /mnt/dst

# Bei btrfs und Timeshift befindet sich das Rootverzeichnis 
# im Subvolume '/@'
# Auf dem Ziel das Subvolume anlegen:
#
```
### Subvolumes anlegen
```sh
cd /dev/dst/
btrfs subvolume create @

# ggf. so alle Subvolumes anlegen, die nötig sind. 
# 
```
### Mit rsync kopieren
```sh
# mit rsync kopieren
# ACHTUNG bei der Quelle mit trailing / beim Ziel nicht
root@lanb109:~# rsync --stats --progress --numeric-ids -axAhHP  /mnt/src/@/ /mnt/dst/@

# Wenn es schnell gehen muss dann "--stats --progress" durch "--quiet" ersetzen.
#
#  Das Ganze für alle zu kopierenden Partitionen durchführen
```
### Capabilities ermitteln und setzen
```
# eine Programme (bsp. ping) benötigen bestimmte Capabilities
#
# ermitteln der Programme und Capabilities
cd /mnt/src/@
root@lanb109:/mnt/src/@# for i in bin/*; do getcap "$i"; done  
bin/kwin_wayland cap_sys_nice=ep  
bin/ping cap_net_raw=ep

# Wechsel zur neuen Partition:
# 
cd /mnt/dst/@
root@lanb109:/mnt/dst/@# setcap cap_sys_nice=ep bin/kwin_wayland
root@lanb109:/mnt/dst/@# setcap cap_net_raw=ep bin/ping

# 
root@lanb109:/mnt/dst/@# cd
root@lanb109:~# umount /mnt/src
root@lanb109:~# umount /mnt/dst

# Das ganze für alle zu kopierenden Partitionen
# durchführen
```

### alten Datenträger entfernen.
### UUIDs in der neuen fstab anpassen

```sh

# root werden
la@lanb109:~$ sudo -i

# mit lsblk die UUIDs der neuen Partitionen ermitteln:
root@lanb109:~# lsblk -f
                                                                                    
├─nvme0n1p1 vfat      FAT32 EFI       5031-120C                             190,8M     3% /boot/efi  
├─nvme0n1p2 btrfs           ROOT      516a8ebd-9e9d-4a9b-9e6e-9232509084ec  144,5G    41%  /  
├─nvme0n1p3 btrfs           HOME      e20e3d90-69f4-4d11-b2ea-50da615d7a84  346,3G    46% /home  

```

### GRUB2 installieren
```sh
# Die Partionen einhängen:
#
root@lanb109:~# mkdir /mnt/{root,home}
root@lanb109:~# mount /dev/nvme0n1p2 -o subvol=/@  /mnt/
root@lanb109:~# mount /dev/nvme0n1p3 -o subvol=/@home /mnt/home
root@lanb109:~# mount /dev/nvme0n1p1 /mnt/boot/efi

# in /mnt/etc/fstab die UUIDs der Partitionen anpassen.

# GRUB2 installieren:
# 
# Dateisysteme für chroot Umgebung bereitstellen:
root@lanb109:~# mount -o bind /dev /mnt/dev
root@lanb109:~# mount -o bind /sys /mnt/sys
root@lanb109:~# mount -t proc /proc /mnt/proc
# 
#   Hier weitere Partitionen (sieh fstab) einhängen
# 
# Wechsel in das neue System
root@lanb109:~# chroot /mnt
root@lanb109:~# update-grub2
root@lanb109:~# grub-install /dev/....
root@lanb109:~# update-grub

```


## Abschließende Schritte[¶](https://wiki.ubuntuusers.de/Ubuntu_umziehen/#Abschliessende-Schritte)

Es sollten noch die beiden Dateien `70-persistent-cd.rules` und `70-persistent-net.rules` im Verzeichnis `/mnt/etc/udev/rules.d` des neuen Datenträgers gelöscht werden. Dort hat das [Udev](https://wiki.ubuntuusers.de/udev/)-System die Einstellungen für Netzwerkkarte bzw. optisches Laufwerk des Originalsystems hinterlegt. Fehlen diese Dateien, werden sie beim Booten des neuen Systems entsprechend angelegt.

Nach einem Neustart sollte der Rechner jetzt mit dem umgezogenen System normal starten. Bei Problemen startet man den Rechner erneut mit der Live-DVD und kontrolliert nochmal sorgfältig die UUIDs und die GRUB 2-Konfiguration.

Falls der Ruhezustand (suspend-to-disk) genutzt werden soll, muss die Datei `/etc/initramfs-tools/conf.d/resume` mit Root-Rechten editiert werden und folgende Zeile eingefügt bzw. mit der eigenen Swap- <UUID> angepasst werden:

`RESUME=UUID=<UUID>`

Eventuell ist es zusätzlich notwendig, `/etc/uswsusp.conf` und/oder `/etc/suspend.conf`  anzupassen:

`resume device = /dev/disk/by-uuid/<UUID>`


Danach muss das initrd-Image neu geschrieben werden, das geht über folgenden Terminalbefehl:

```sh
sudo update-initramfs -u
```

Siehe auch: [https://wiki.ubuntuusers.de/Ubuntu_umziehen/]()
