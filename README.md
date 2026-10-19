# Digital Dealer — operator seat install

One line sets up an operator seat on your own computer. It signs you in to GitHub in the browser, fetches the seat
installer from the team repository (which your sign-in gives you access to) and runs it. Run the same line again any time
to update your seat.

**Mac** — open Terminal (press ⌘ and Space, type Terminal, press Return), paste, press Return:

```
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/digitaldealer-au/seat/main/install.sh)"
```

**Ubuntu inside Windows (WSL)** — open your Ubuntu window and paste the same line as the Mac, then press Return.

**Windows** — open PowerShell (press the Windows key, type PowerShell, press Enter), paste, press Enter:

```
irm https://raw.githubusercontent.com/digitaldealer-au/seat/main/install.ps1 | iex
```

The two scripts here hold nothing private: they fetch the GitHub tool from its public release, open the browser sign-in,
and hand over to the installer in the team repository. Ask Andre for the Operator Seat Manual.
