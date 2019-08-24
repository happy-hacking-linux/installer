## installer

Graphical installation wizard for Happy Hacking Linux.

## Usage

#### Creating ISO

You'll get an iso file under `./iso/out` folder after running;

```bash
$ make create-iso
```

#### In Arch Linux

You can install Arch Linux with this wizard by simply calling it;

```
curl -L https://git.io/v1JNj | bash
```

## Todo

Tasks need to be done for the next release:

* Add `playerctl` to the default setup. Xmonad config is ready to hook up with it.
* Add `pacaur` to the default setup.
* Detect if the system is a notebook by running `dmidecode --string chassis-type` and do some customizations for laptops such as installing `laptop-mode-tools`
* Add `fd-rs` to the default setup.
* Install Asian font sets by default. (adobe-source-han-serif-otc-fonts and adobe-source-han-sans-otc-fonts)
* Read partition names under selected disk using `lsblk`. 
* Install Rofi & make it default app selector
* Diff http://termbin.com/3vfor
* Install `ttf-symbola` 
* Install `udevil` instead of `udiskie`
