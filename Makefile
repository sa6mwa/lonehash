.PHONY: help configure build build-debug build-release test test-debug test-all asan \
	bench benchmarks bench-gate package package-source package-source-smoke \
	package-checksums package-verify verify-release-archives verify-release-privacy \
	release-matrix finalize-slice prerelease prerelease-hardening release \
	print-release-version format clean clean-dist

help:
	@printf '%s\n' \
	  'build                  Configure and build debug preset' \
	  'test                   Run debug tests' \
	  'asan                   Build and run ASan/UBSan preset' \
	  'bench                  Run local benchmarks' \
	  'package                Build host binary SDK tarball' \
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

test-all: test asan

asan:
	cmake --preset asan
	cmake --build --preset asan
	ctest --preset asan

bench benchmarks: build-debug
	./build/debug/lonehash_bench

bench-gate: bench

package: build-release
	scripts/package.sh host release

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

prerelease-hardening: prerelease package package-checksums package-verify

release: clean prerelease-hardening

print-release-version:
	@scripts/release_version.sh

format:
	clang-format -i src/*.c tests/*.c examples/*.c bench/*.c

clean:
	rm -rf build dist .cache

clean-dist:
	rm -rf dist
