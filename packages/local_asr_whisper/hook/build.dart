/// Purpose: Build whisper.cpp from the pinned submodule for the target the
/// Flutter tool is building, and hand the libraries to it as code assets.
/// Inputs: The hook input: target OS and architecture, the C toolchain Flutter
/// found, and a shared output directory for incremental builds.
/// Returns: Code assets — the `lasr_whisper` shim the Dart bindings name, and
/// every library it needs beside it.
/// Side effects: Runs CMake and Ninja; writes into the hook's output folders.
/// Notes: One CMake project (`src/CMakeLists.txt`) for every target; what
/// differs is the compiler and the ggml options:
///
/// - **Windows** is compiled with clang from the Visual Studio LLVM component,
///   not `cl.exe`, which lacks the FP16 intrinsics ggml uses on ARM64 (decision
///   D9 of the local-models plan). x64 builds every CPU variant and loads the
///   best at run time; ARM64 cannot (the pinned ggml has no Windows ARM64
///   variant list), so it is one library at a baseline every Windows 11 ARM
///   processor has: ARMv8.2 with dot-product and FP16.
/// - **Android** builds every CPU variant for arm64 and x86_64 and loads the
///   best at run time. 32-bit targets are not built: a large Whisper model does
///   not fit a 32-bit address space, and the adapter reports the engine as not
///   built there.
/// - **Apple** links Metal and the CPU backend into one library; Metal is part
///   of the OS, so there is no missing driver to guard against.
/// - **Linux** is the host `flutter test` runs on in CI: one library at the
///   default baseline.
///
/// Tools are found on PATH, then in Visual Studio's bundled CMake and Ninja on
/// Windows, then in the Android SDK's CMake for Android. See
/// `doc/en-us/platform-notes.md`.
library;

import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';

/// Purpose: Run the hook.
/// Inputs: The arguments the Flutter tool passes.
/// Returns: None.
/// Side effects: Builds and reports the libraries.
/// Notes: A target this package cannot build for — 32-bit, or an OS without a
/// toolchain — reports no assets rather than failing the app's build: the app
/// still runs there, without this engine.
Future<void> main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets) return;
    final code = input.config.code;
    final os = code.targetOS;
    final arch = code.targetArchitecture;
    if (!_supported(os, arch)) return;

    final packageRoot = Directory.fromUri(input.packageRoot);
    final source = Directory('${packageRoot.path}src');
    final whisper = Directory('${packageRoot.path}../whisper.cpp');
    if (!File('${whisper.path}/CMakeLists.txt').existsSync()) {
      throw StateError(
        'packages/whisper.cpp is empty; run `git submodule update --init`.',
      );
    }

    final buildDir = Directory.fromUri(
      input.outputDirectoryShared.resolve('cmake-${os.name}-${arch.name}/'),
    );
    await buildDir.create(recursive: true);

    final toolchain = await _Toolchain.resolve(code);
    await _run(toolchain.cmake, [
      '-S',
      source.path,
      '-B',
      buildDir.path,
      '-G',
      if (toolchain.ninja case final ninja?) ...[
        'Ninja',
        '-DCMAKE_MAKE_PROGRAM=$ninja',
      ] else
        'Unix Makefiles',
      '-DCMAKE_BUILD_TYPE=Release',
      '-DWHISPER_SOURCE_DIR=${whisper.absolute.path.replaceAll(r'\', '/')}',
      '-DBUILD_SHARED_LIBS=${_dynamicBackends(os, arch) ? 'ON' : 'OFF'}',
      '-DGGML_NATIVE=OFF',
      '-DGGML_OPENMP=OFF',
      // ggml wraps the compiler in ccache when it finds one, and ccache fails
      // in the reduced environment a hook runs in (no LOCALAPPDATA on a
      // Windows runner). The hook's own build folder is already incremental.
      '-DGGML_CCACHE=OFF',
      // Where ggml and whisper are static libraries, they are linked into the
      // shared shim, which on Linux needs them compiled position-independent.
      '-DCMAKE_POSITION_INDEPENDENT_CODE=ON',
      ...toolchain.cmakeArgs,
      ..._ggmlArgs(os, arch),
    ], environment: toolchain.environment);
    await _run(toolchain.cmake, [
      '--build',
      buildDir.path,
      '--config',
      'Release',
    ], environment: toolchain.environment);

    final bin = Directory('${buildDir.path}/bin');
    final libraries = [
      for (final entry in bin.listSync())
        if (entry is File && _isLibrary(entry.path, os)) entry,
    ];
    final shim = libraries.firstWhere(
      (file) => _baseName(file.path).contains('lasr_whisper'),
      orElse: () => throw StateError('The build produced no lasr_whisper.'),
    );

    output.assets.code.add(
      CodeAsset(
        package: input.packageName,
        name: 'src/bindings.dart',
        linkMode: DynamicLoadingBundled(),
        file: shim.uri,
      ),
    );
    for (final library in libraries) {
      if (library.path == shim.path) continue;
      // Parakeet ships in the same tree but nothing here uses it yet.
      if (_baseName(library.path).contains('parakeet')) continue;
      output.assets.code.add(
        CodeAsset(
          package: input.packageName,
          name: 'lib/${_baseName(library.path)}',
          linkMode: DynamicLoadingBundled(),
          file: library.uri,
        ),
      );
    }

    output.dependencies.addAll([
      for (final entry in source.listSync())
        if (entry is File) entry.uri,
      File('${whisper.path}/CMakeLists.txt').uri,
      File('${whisper.path}/include/whisper.h').uri,
      File('${whisper.path}/ggml/CMakeLists.txt').uri,
    ]);
  });
}

/// Purpose: Say whether this package builds for a target at all.
/// Inputs: [os], [arch].
/// Returns: `bool`.
/// Side effects: None.
/// Notes: Internal helper used within this file only.
bool _supported(OS os, Architecture arch) => switch (os) {
  OS.android => arch == Architecture.arm64 || arch == Architecture.x64,
  OS.windows => arch == Architecture.arm64 || arch == Architecture.x64,
  OS.macOS || OS.iOS => arch == Architecture.arm64 || arch == Architecture.x64,
  OS.linux => arch == Architecture.x64 || arch == Architecture.arm64,
  _ => false,
};

/// Purpose: Say whether ggml's backends are separate libraries on a target.
/// Inputs: [os], [arch].
/// Returns: `bool`.
/// Side effects: None.
/// Notes: Internal helper used within this file only. Only where the pinned
/// ggml can build several CPU variants and pick one at run time; everywhere
/// else one library is simpler to bundle and to load.
bool _dynamicBackends(OS os, Architecture arch) =>
    os == OS.android || (os == OS.windows && arch == Architecture.x64);

/// Purpose: The ggml and whisper options for a target.
/// Inputs: [os], [arch].
/// Returns: CMake `-D` arguments.
/// Side effects: None.
/// Notes: Internal helper used within this file only.
List<String> _ggmlArgs(OS os, Architecture arch) => [
  if (_dynamicBackends(os, arch)) ...[
    '-DGGML_BACKEND_DL=ON',
    '-DGGML_CPU_ALL_VARIANTS=ON',
  ],
  if (os == OS.windows && arch == Architecture.arm64)
    '-DGGML_CPU_ARM_ARCH=armv8.2-a+dotprod+fp16',
  if (os == OS.macOS || os == OS.iOS) ...[
    '-DGGML_METAL=ON',
    '-DGGML_METAL_EMBED_LIBRARY=ON',
    // The Core ML encoder beside a model is used when it is there, and its
    // absence falls back to Metal rather than failing the load.
    '-DWHISPER_COREML=ON',
    '-DWHISPER_COREML_ALLOW_FALLBACK=ON',
    '-DGGML_BLAS=OFF',
  ],
];

/// Purpose: Say whether a build output is a shared library for [os].
/// Inputs: The file [path] and [os].
/// Returns: `bool`.
/// Side effects: None.
/// Notes: Internal helper used within this file only.
bool _isLibrary(String path, OS os) => switch (os) {
  OS.windows => path.endsWith('.dll'),
  OS.macOS || OS.iOS => path.endsWith('.dylib'),
  _ => path.endsWith('.so'),
};

/// Purpose: The last path segment.
/// Inputs: [path].
/// Returns: The file name.
/// Side effects: None.
/// Notes: Internal helper used within this file only.
String _baseName(String path) => path.split(RegExp(r'[\\/]')).last;

/// Purpose: Run a tool and fail the hook with its output when it fails.
/// Inputs: The [executable], its [arguments], and the [environment].
/// Returns: None.
/// Side effects: Runs a process.
/// Notes: Internal helper used within this file only.
Future<void> _run(
  String executable,
  List<String> arguments, {
  Map<String, String>? environment,
}) async {
  final result = await Process.run(
    executable,
    arguments,
    environment: environment,
    includeParentEnvironment: environment == null,
  );
  if (result.exitCode != 0) {
    throw ProcessException(
      executable,
      arguments,
      '${result.stdout}\n${result.stderr}',
      result.exitCode,
    );
  }
}

/// The tools and settings for one target.
class _Toolchain {
  _Toolchain({
    required this.cmake,
    required this.ninja,
    required this.cmakeArgs,
    this.environment,
  });

  /// The CMake executable.
  final String cmake;

  /// The Ninja executable, or null to use Makefiles.
  ///
  /// Only off Windows: a macOS runner may have CMake and not Ninja, and
  /// Xcode's make serves as well there.
  final String? ninja;

  /// The compiler and platform arguments.
  final List<String> cmakeArgs;

  /// The whole environment to run in, or null for the hook's own.
  final Map<String, String>? environment;

  /// Purpose: Find the tools for the target in [code].
  /// Inputs: [code], the hook's code config.
  /// Returns: A [_Toolchain].
  /// Side effects: May run Visual Studio's environment script.
  /// Notes: None.
  static Future<_Toolchain> resolve(CodeConfig code) async =>
      switch (code.targetOS) {
        OS.windows => _windows(code),
        OS.android => _android(code),
        OS.macOS || OS.iOS => _apple(code),
        _ => _Toolchain(
          cmake: _onPath('cmake') ?? 'cmake',
          ninja: _onPath('ninja'),
          cmakeArgs: const [],
        ),
      };

  /// Purpose: Windows: clang from Visual Studio, in its developer environment.
  /// Inputs: [code].
  /// Returns: A [_Toolchain].
  /// Side effects: Runs the developer command prompt script once.
  /// Notes: The Flutter tool hands over `cl.exe` and the environment script;
  /// the LLVM component lives beside `cl.exe` in the same Visual Studio.
  static Future<_Toolchain> _windows(CodeConfig code) async {
    final compiler = code.cCompiler;
    final hostArm = Abi.current() == Abi.windowsArm64;
    final Directory vc;
    final String script;
    final List<String> scriptArguments;
    if (compiler != null) {
      // …\VC\Tools\MSVC\<version>\bin\Host<h>\<t>\cl.exe → …\VC
      var dir = File.fromUri(compiler.compiler).parent;
      for (var i = 0; i < 6; i++) {
        dir = dir.parent;
      }
      vc = dir;
      final prompt = compiler.windows.developerCommandPrompt;
      script = prompt == null ? '' : File.fromUri(prompt.script).path;
      scriptArguments = prompt?.arguments ?? const [];
    } else {
      // `dart test` hands over no toolchain on Windows; the Flutter tool does.
      vc = Directory('${_visualStudio().path}\\VC');
      script = '${vc.path}\\Auxiliary\\Build\\vcvarsall.bat';
      final host = hostArm ? 'arm64' : 'x64';
      final target = code.targetArchitecture == Architecture.arm64
          ? 'arm64'
          : 'x64';
      scriptArguments = [host == target ? target : '${host}_$target'];
    }
    final llvm =
        [
          if (hostArm) '${vc.path}\\Tools\\Llvm\\ARM64\\bin',
          '${vc.path}\\Tools\\Llvm\\x64\\bin',
          '${vc.path}\\Tools\\Llvm\\bin',
          // A standalone LLVM, as CI installs where Visual Studio lacks the
          // Clang component.
          if (Platform.environment['LLVM_ROOT'] case final root?) '$root\\bin',
          r'C:\Program Files\LLVM\bin',
        ].firstWhere(
          (dir) => File('$dir\\clang.exe').existsSync(),
          orElse: () => throw StateError(
            'Clang is not installed with Visual Studio. Add the "C++ Clang '
            'Compiler for Windows" component, or install LLVM.',
          ),
        );
    final ide = '${vc.parent.path}\\Common7\\IDE\\CommonExtensions\\Microsoft';

    final environment = <String, String>{...Platform.environment};
    if (script.isNotEmpty) {
      final result = await Process.run('cmd', [
        '/c',
        'call',
        script,
        ...scriptArguments,
        '>nul',
        '&&',
        'set',
      ]);
      for (final line in '${result.stdout}'.split(RegExp(r'\r?\n'))) {
        final at = line.indexOf('=');
        if (at > 0) environment[line.substring(0, at)] = line.substring(at + 1);
      }
    }

    final target = code.targetArchitecture == Architecture.arm64
        ? 'arm64-pc-windows-msvc'
        : 'x86_64-pc-windows-msvc';
    final clang = '$llvm\\clang.exe'.replaceAll(r'\', '/');
    final clangxx = '$llvm\\clang++.exe'.replaceAll(r'\', '/');
    // On x64, ggml's SSE4.2 variant passes block pointers to `_mm_prefetch`,
    // which the MSVC-compatible headers declare as taking `const char *`; a
    // clang recent enough to make that an error stops the build over a
    // prefetch hint. It stays a warning.
    final flags = code.targetArchitecture == Architecture.arm64
        ? '-march=armv8.2-a+dotprod+fp16 -fvectorize -ffp-model=fast'
        : '-fvectorize -ffp-model=fast '
              '-Wno-error=incompatible-pointer-types';
    return _Toolchain(
      cmake:
          _onPath('cmake', environment) ?? '$ide\\CMake\\CMake\\bin\\cmake.exe',
      ninja: (_onPath('ninja', environment) ?? '$ide\\CMake\\Ninja\\ninja.exe')
          .replaceAll(r'\', '/'),
      cmakeArgs: [
        '-DCMAKE_SYSTEM_NAME=Windows',
        '-DCMAKE_SYSTEM_PROCESSOR=${code.targetArchitecture == Architecture.arm64 ? 'ARM64' : 'AMD64'}',
        '-DCMAKE_C_COMPILER=$clang',
        '-DCMAKE_CXX_COMPILER=$clangxx',
        '-DCMAKE_C_COMPILER_TARGET=$target',
        '-DCMAKE_CXX_COMPILER_TARGET=$target',
        '-DCMAKE_C_FLAGS=$flags',
        '-DCMAKE_CXX_FLAGS=$flags',
      ],
      environment: environment,
    );
  }

  /// Purpose: Android: the NDK's own CMake toolchain file.
  /// Inputs: [code].
  /// Returns: A [_Toolchain].
  /// Side effects: None.
  /// Notes: The NDK root is found from the clang the Flutter tool hands over;
  /// CMake and Ninja come from the Android SDK when they are not on PATH.
  static Future<_Toolchain> _android(CodeConfig code) async {
    final compiler = code.cCompiler;
    if (compiler == null) {
      throw StateError('No NDK toolchain was found for Android.');
    }
    // <ndk>/toolchains/llvm/prebuilt/<host>/bin/clang → <ndk>
    var ndk = File.fromUri(compiler.compiler).parent;
    for (var i = 0; i < 5; i++) {
      ndk = ndk.parent;
    }
    final sdk = ndk.parent.parent;
    String? sdkTool(String name) {
      final cmakeDir = Directory('${sdk.path}/cmake');
      if (!cmakeDir.existsSync()) return null;
      final versions = cmakeDir.listSync().whereType<Directory>().toList()
        ..sort((a, b) => b.path.compareTo(a.path));
      for (final version in versions) {
        for (final candidate in [
          '${version.path}/bin/$name',
          '${version.path}/bin/$name.exe',
        ]) {
          if (File(candidate).existsSync()) return candidate;
        }
      }
      return null;
    }

    final abi = switch (code.targetArchitecture) {
      Architecture.arm64 => 'arm64-v8a',
      Architecture.x64 => 'x86_64',
      final other => throw StateError('Unsupported Android ABI: $other'),
    };
    return _Toolchain(
      cmake: _onPath('cmake') ?? sdkTool('cmake') ?? 'cmake',
      ninja: (_onPath('ninja') ?? sdkTool('ninja'))?.replaceAll(r'\', '/'),
      cmakeArgs: [
        '-DCMAKE_TOOLCHAIN_FILE=${ndk.path.replaceAll(r'\', '/')}/build/cmake/android.toolchain.cmake',
        '-DANDROID_ABI=$abi',
        '-DANDROID_PLATFORM=android-${code.android.targetNdkApi}',
        '-DANDROID_STL=c++_static',
      ],
    );
  }

  /// Purpose: macOS and iOS: Xcode's clang, one architecture per call.
  /// Inputs: [code].
  /// Returns: A [_Toolchain].
  /// Side effects: None.
  /// Notes: The Flutter tool calls the hook once per architecture and joins
  /// the results itself.
  static Future<_Toolchain> _apple(CodeConfig code) async {
    final arch = code.targetArchitecture == Architecture.arm64
        ? 'arm64'
        : 'x86_64';
    final ios = code.targetOS == OS.iOS;
    return _Toolchain(
      cmake: _onPath('cmake') ?? 'cmake',
      ninja: _onPath('ninja'),
      cmakeArgs: [
        '-DCMAKE_OSX_ARCHITECTURES=$arch',
        if (ios) ...[
          '-DCMAKE_SYSTEM_NAME=iOS',
          '-DCMAKE_OSX_SYSROOT=${code.iOS.targetSdk == IOSSdk.iPhoneSimulator ? 'iphonesimulator' : 'iphoneos'}',
          '-DCMAKE_OSX_DEPLOYMENT_TARGET=${code.iOS.targetVersion}',
        ] else
          '-DCMAKE_OSX_DEPLOYMENT_TARGET=${code.macOS.targetVersion}',
      ],
    );
  }
}

/// Purpose: Find the newest Visual Studio installation.
/// Inputs: None.
/// Returns: Its root directory.
/// Side effects: Reads the file system.
/// Notes: Internal helper used within this file only. Looks in the default
/// install locations, newest version first, for one with the C++ tools.
Directory _visualStudio() {
  for (final base in [
    r'C:\Program Files\Microsoft Visual Studio',
    r'C:\Program Files (x86)\Microsoft Visual Studio',
  ]) {
    final root = Directory(base);
    if (!root.existsSync()) continue;
    final versions = root.listSync().whereType<Directory>().toList()
      ..sort((a, b) => b.path.compareTo(a.path));
    for (final version in versions) {
      final editions = version.listSync().whereType<Directory>();
      for (final edition in editions) {
        if (File(
          '${edition.path}\\VC\\Auxiliary\\Build\\vcvarsall.bat',
        ).existsSync()) {
          return edition;
        }
      }
    }
  }
  throw StateError(
    'Visual Studio with the C++ tools was not found; install it with the '
    '"Desktop development with C++" workload and the Clang component.',
  );
}

/// Purpose: Find an executable on PATH.
/// Inputs: The tool's [name], and optionally the [environment] to search.
/// Returns: Its path, or null.
/// Side effects: Reads the file system.
/// Notes: Internal helper used within this file only.
String? _onPath(String name, [Map<String, String>? environment]) {
  final path =
      (environment ?? Platform.environment)['PATH'] ??
      (environment ?? Platform.environment)['Path'] ??
      '';
  final separator = Platform.isWindows ? ';' : ':';
  final suffixes = Platform.isWindows ? ['.exe', '.cmd', ''] : [''];
  for (final dir in path.split(separator)) {
    if (dir.isEmpty) continue;
    for (final suffix in suffixes) {
      final candidate = File('$dir${Platform.pathSeparator}$name$suffix');
      if (candidate.existsSync()) return candidate.path;
    }
  }
  return null;
}
