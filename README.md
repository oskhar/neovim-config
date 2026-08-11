# AstroNvim Template

**NOTE:** This is for AstroNvim v5+

A template for getting started with [AstroNvim](https://github.com/AstroNvim/AstroNvim)

## 🛠️ Installation

#### Make a backup of your current nvim and shared folder

```shell
mv ~/.config/nvim ~/.config/nvim.bak
mv ~/.local/share/nvim ~/.local/share/nvim.bak
mv ~/.local/state/nvim ~/.local/state/nvim.bak
mv ~/.cache/nvim ~/.cache/nvim.bak
```

#### Create a new user repository from this template

Press the "Use this template" button above to create a new repository to store your user configuration.

You can also just clone this repository directly if you do not want to track your user configuration in GitHub.

#### Clone the repository

```shell
git clone https://github.com/<your_user>/<your_repository> ~/.config/nvim
```

#### Start Neovim

```shell
nvim
```

## Spring Initializr TUI (Arch Linux)

Installer ini memasang release native terbaru dari
[Spring Initializr TUI](https://github.com/danvega/spring-initializr-tui) ke
`~/.local/bin/spring-tui`. Tidak membutuhkan JDK dan tidak menggunakan `sudo`.

```shell
~/.config/nvim/scripts/install-spring-tui.sh
```

Setelah instalasi, buka direktori tempat proyek baru akan dibuat lalu jalankan:

```shell
mkdir -p ~/Projects
cd ~/Projects
spring-tui
```

Script aman dijalankan kembali untuk memasang release terbaru. Lokasi instalasi
dapat diganti jika diperlukan:

```shell
INSTALL_DIR="$HOME/bin" ~/.config/nvim/scripts/install-spring-tui.sh
```
