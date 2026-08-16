.PHONY: help deps-debug deps-release deps-cross configure build build-debug build-release test test-debug test-all valgrind lua-test lua-artifacts asan \
	bench benchmarks bench-gate package package-cli package-source package-source-smoke \
	package-checksums package-verify verify-release-archives verify-release-privacy \
	release-matrix finalize-slice prerelease prerelease-hardening release \
	print-release-version format clean clean-dist

help:
	@printf '%s\n' \
	  'build                  Configure and build debug preset' \
	  'deps-debug             Provision the pinned native Linux toolchain' \
	  'deps-release           Provision all pinned Linux release toolchains' \
	  'deps-cross             Provision non-native Linux release toolchains' \
	  'test                   Run debug tests' \
	  'valgrind               Run native debug tests under Valgrind Memcheck' \
	  'lua-test               Run Lua facade smoke tests against build/release' \
	  'release-lua-artifacts  Build Lua source tarball, rockspec, and source rock' \
	  'asan                   Build and run ASan/UBSan preset' \
	  'bench                  Run release-build local benchmarks' \
	  'package                Build native Linux library SDK and lh CLI tarballs' \
	  'package-cli            Build native Linux lh CLI tarball' \
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

deps-debug:
	scripts/cpkt-toolchains.sh ensure x86_64-linux-gnu

deps-release:
	scripts/cpkt-toolchains.sh ensure all

deps-cross:
	@for target in x86_64-linux-musl aarch64-linux-gnu aarch64-linux-musl armhf-linux-gnu armhf-linux-musl; do \
	  scripts/cpkt-toolchains.sh ensure $$target; \
	done

configure:
	cmake --preset debug

build build-debug: configure
	cmake --build --preset debug

build-release:
	cmake --preset release
	cmake --build --preset release

test test-debug: build-debug
	ctest --preset debug

valgrind:
	@command -v valgrind >/dev/null 2>&1 || { echo 'valgrind is required for this native hardening gate' >&2; exit 1; }
	cmake --preset valgrind
	cmake --build --preset valgrind
	LONEHASH_TEST_SKIP_LARGE=1 valgrind --leak-check=full --track-origins=yes --error-exitcode=1 ./build/valgrind/lonehash_tests

lua-test: build-release
	tests/test_lua.sh "$$(pwd)" "$$(pwd)/build/release"

lua-artifacts release-lua-artifacts:
	scripts/package_lua.sh

test-all: test asan valgrind

asan:
	cmake --preset asan
	cmake --build --preset asan
	ctest --preset asan

bench benchmarks: build-release
	./build/release/lonehash_bench

bench-gate: bench

package: build-release package-cli
	scripts/package.sh x86_64-linux-gnu release

package-cli: build-release
	scripts/package_cli.sh x86_64-linux-gnu release

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

prerelease: finalize-slice lua-test asan valgrind package-source-smoke

prerelease-hardening: prerelease release-matrix

release: clean prerelease-hardening

print-release-version:
	@scripts/release_version.sh

format:
	clang-format -i src/*.c tests/*.c examples/*.c bench/*.c lua/lonehash/*.c

clean:
	rm -rf build dist .cache

clean-dist:
	rm -rf dist
