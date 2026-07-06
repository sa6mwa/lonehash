.PHONY: help configure build build-debug build-release test test-debug test-all lua-test lua-artifacts asan \
	bench benchmarks bench-gate package package-cli package-source package-source-smoke \
	package-checksums package-verify verify-release-archives verify-release-privacy \
	release-matrix finalize-slice prerelease prerelease-hardening release \
	print-release-version format clean clean-dist

help:
	@printf '%s\n' \
	  'build                  Configure and build debug preset' \
	  'test                   Run debug tests' \
	  'lua-test               Run Lua facade smoke tests against build/release' \
	  'lua-artifacts          Build Lua source tarball, rockspec, and source rock' \
	  'asan                   Build and run ASan/UBSan preset' \
	  'bench                  Run release-build local benchmarks' \
	  'package                Build host library SDK and lh CLI tarballs' \
	  'package-cli            Build host lh CLI tarball' \
	  'package-source         Build source tarball' \
	  'package-source-smoke   Extract/build/test source tarball' \
	  'package-checksums      Generate SHA-256 release checksum manifest' \
	  'package-verify         Verify checksum-listed release artifacts' \
	  'release-matrix         Build/package all configured target presets' \
	  'finalize-slice         Format, build, and run debug tests' \
	  'prerelease             Deterministic local pre-release gate' \
	  'prerelease-hardening   Prerelease plus package verification' \
	  'release                Clean final local release build and verification' \
	  'print-release-version  Print resolved release version' \
	  'format                 Run clang-format over project C files' \
	  'clean                  Remove generated build/dist/cache state' \
	  'clean-dist             Remove dist artifacts'

configure:
	cmake --preset debug

build build-debug: configure
	cmake --build --preset debug

build-release:
	cmake --preset release
	cmake --build --preset release

test test-debug: build-debug
	ctest --preset debug

lua-test: build-release
	tests/test_lua.sh "$$(pwd)" "$$(pwd)/build/release"

lua-artifacts:
	scripts/package_lua.sh

test-all: test asan

asan:
	cmake --preset asan
	cmake --build --preset asan
	ctest --preset asan

bench benchmarks: build-release
	./build/release/lonehash_bench

bench-gate: bench

package: build-release package-cli
	scripts/package.sh host release

package-cli: build-release
	scripts/package_cli.sh host release

package-source:
	scripts/package_source.sh

package-source-smoke: package-source
	scripts/source_smoke.sh

package-checksums:
	scripts/package_checksums.sh

package-verify:
	scripts/package_verify.sh

verify-release-archives verify-release-privacy: package-verify

release-matrix:
	scripts/release_matrix.sh

finalize-slice: format test

prerelease: finalize-slice asan package-source-smoke

prerelease-hardening: prerelease package lua-artifacts package-checksums package-verify

release: clean prerelease-hardening

print-release-version:
	@scripts/release_version.sh

format:
	clang-format -i src/*.c tests/*.c examples/*.c bench/*.c lua/lonehash/*.c

clean:
	rm -rf build dist .cache

clean-dist:
	rm -rf dist
