# Changelog

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
