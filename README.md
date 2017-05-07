# vim-ecfg

## Overview
This plugin is just hacky magic wrapping around ecfg to make it play nicely with
vim. I make no guarantees that it won't make things go horribly wrong.

## Installation
Just stick it in your `.vim/bundle` folder.
```bash
mkdir -p ~/.vim/bundle
cd ~/.vim/bundle
git clone https://github.com/santiclause/vim-ecfg
```

## Requirements
Use pathogen, unless you want to manually include it.

You gotta have +python in your vim, if you want to read decrypted files.
Otherwise, you just get barebones automatic encryption (the same as if you
didn't have the private key to decrypt a file).

## Motivation
I originally had some simple vim magic that would decrypt ecfg files on read,
and encrypt them on write. Unfortunately, this re-encrypts _every_ single value
(since I decrypted them on the way in), which makes it look like I touched
every value in git blame. Gross! Can't have that - but I still wanted to be
able to decrypt and encrypt automatically.

## Implementation
Fundamentally, it's just diffing the decrypted values and then applying that
diff as a patch on the _encrypted_ base file, and then re-encrypting after
applying the patch.
