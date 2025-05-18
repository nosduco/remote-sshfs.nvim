# Changelog

## [0.3.6](https://github.com/nosduco/remote-sshfs.nvim/compare/v0.3.5...v0.3.6) (2025-05-18)


### Bug Fixes

* rename enable to enabled to fix mismatched config option for logging ([#36](https://github.com/nosduco/remote-sshfs.nvim/issues/36)) ([a1bea01](https://github.com/nosduco/remote-sshfs.nvim/commit/a1bea018c1b43ca8cc8a6e9adc4128e07610fd34))

## [0.3.5](https://github.com/nosduco/remote-sshfs.nvim/compare/v0.3.4...v0.3.5) (2025-03-28)


### Bug Fixes

* fix keybinds example in README ([#32](https://github.com/nosduco/remote-sshfs.nvim/issues/32)) ([e047b63](https://github.com/nosduco/remote-sshfs.nvim/commit/e047b6340653538efa57a8164cdcb1f729325689))

## [0.3.4](https://github.com/nosduco/remote-sshfs.nvim/compare/v0.3.3...v0.3.4) (2024-08-29)


### Bug Fixes

* ensure insert mode on confirm inputs [#28](https://github.com/nosduco/remote-sshfs.nvim/issues/28) ([c66f203](https://github.com/nosduco/remote-sshfs.nvim/commit/c66f2032bacf9c3cc5365d4e157a68876dbbb9ab))

## [0.3.3](https://github.com/nosduco/remote-sshfs.nvim/compare/v0.3.2...v0.3.3) (2024-06-11)


### Bug Fixes

* remove local user fallback ([#25](https://github.com/nosduco/remote-sshfs.nvim/issues/25)) ([b133f5f](https://github.com/nosduco/remote-sshfs.nvim/commit/b133f5f4262a92a7ce1b867abaf511cf22eccea7))

## [0.3.2](https://github.com/nosduco/remote-sshfs.nvim/compare/v0.3.1...v0.3.2) (2024-05-25)


### Bug Fixes

* ssh config hosts with multiple hostnames [#11](https://github.com/nosduco/remote-sshfs.nvim/issues/11) ([f1c0af4](https://github.com/nosduco/remote-sshfs.nvim/commit/f1c0af44362ebf475ee01a13377a42b17b348df7))

## [0.3.1](https://github.com/nosduco/remote-sshfs.nvim/compare/v0.3.0...v0.3.1) (2024-01-08)


### Bug Fixes

* empty argument processing for :RemoveSSHFSConnect command. fixes [#16](https://github.com/nosduco/remote-sshfs.nvim/issues/16) ([e11dd19](https://github.com/nosduco/remote-sshfs.nvim/commit/e11dd19c2ecf9881022429d1bca08d9bfd95c6c6))

## [0.3.0](https://github.com/nosduco/remote-sshfs.nvim/compare/v0.2.3...v0.3.0) (2023-12-09)


### Features

* add argument to RemoteSSHFSConnect command to directly connect on user, host, path, and port ([#14](https://github.com/nosduco/remote-sshfs.nvim/issues/14)) ([3cebc71](https://github.com/nosduco/remote-sshfs.nvim/commit/3cebc7140ecb56aa613e66e8404a30d31f618b2e))

## [0.2.3](https://github.com/nosduco/remote-sshfs.nvim/compare/v0.2.2...v0.2.3) (2023-12-07)


### Bug Fixes

* pass opts through api layer to telescope extension. [#6](https://github.com/nosduco/remote-sshfs.nvim/issues/6) ([6104abf](https://github.com/nosduco/remote-sshfs.nvim/commit/6104abf11fc891d89ac62f1a972d04d3641b9f96))

## [0.2.2](https://github.com/nosduco/remote-sshfs.nvim/compare/v0.2.1...v0.2.2) (2023-12-07)


### Bug Fixes

* error if ssh config is not readable or does not exist. [#5](https://github.com/nosduco/remote-sshfs.nvim/issues/5) ([ad6a015](https://github.com/nosduco/remote-sshfs.nvim/commit/ad6a015de9ed066e87c80431b77d64e560070330))
* remove hard-coded remote /home directory ([#10](https://github.com/nosduco/remote-sshfs.nvim/issues/10)) ([29908ca](https://github.com/nosduco/remote-sshfs.nvim/commit/29908ca45ebff903d6a0a944acbed0674fbe767d))


### CI/CD

* add release workflow ([1180cdf](https://github.com/nosduco/remote-sshfs.nvim/commit/1180cdf665404c4ec7a766ac6d0457b42e688376))
