// Copyright (c) 2026 Nguyễn Trọng Hà. All rights reserved.
// Project: BVĐKKH - Remote
// Author: Nguyễn Trọng Hà

import 'dart:ffi' hide Size;
import 'dart:io';

import 'package:ffi/ffi.dart';

import 'package:win32/win32.dart' as win32;

/// Get windows target build number.
///
/// [Note]
/// Please use this function wrapped with `Platform.isWindows`.
int getWindowsTargetBuildNumber_() {
  final rtlGetVersion = DynamicLibrary.open('ntdll.dll').lookupFunction<
      Void Function(Pointer<win32.OSVERSIONINFOEX>),
      void Function(Pointer<win32.OSVERSIONINFOEX>)>('RtlGetVersion');
  final osVersionInfo = _getOSVERSIONINFOEXPointer();
  rtlGetVersion(osVersionInfo);
  int buildNumber = osVersionInfo.ref.dwBuildNumber;
  calloc.free(osVersionInfo);
  return buildNumber;
}

/// Get Windows OS version pointer
///
/// [Note]
/// Please use this function wrapped with `Platform.isWindows`.
Pointer<win32.OSVERSIONINFOEX> _getOSVERSIONINFOEXPointer() {
  final pointer = calloc<win32.OSVERSIONINFOEX>();
  pointer.ref
    ..dwOSVersionInfoSize = sizeOf<win32.OSVERSIONINFOEX>()
    ..dwBuildNumber = 0
    ..dwMajorVersion = 0
    ..dwMinorVersion = 0
    ..dwPlatformId = 0
    ..szCSDVersion = ''
    ..wServicePackMajor = 0
    ..wServicePackMinor = 0
    ..wSuiteMask = 0
    ..wProductType = 0
    ..wReserved = 0;
  return pointer;
}

/// Get CPU processor name on Windows (e.g. "11th Gen Intel(R) Core(TM) i7-11800H @ 2.30GHz")
String getWindowsCpuName() {
  try {
    final res = Process.runSync(
      'reg',
      ['query', r'HKLM\HARDWARE\DESCRIPTION\System\CentralProcessor\0', '/v', 'ProcessorNameString'],
      runInShell: true,
    );
    if (res.exitCode == 0) {
      for (final line in res.stdout.toString().split('\n')) {
        if (line.contains('REG_SZ')) {
          final parts = line.split('REG_SZ');
          if (parts.length > 1) {
            final name = parts[1].trim().replaceAll(RegExp(r'\s+'), ' ');
            if (name.isNotEmpty) return name;
          }
        }
      }
    }
  } catch (_) {}
  final envId = Platform.environment['PROCESSOR_IDENTIFIER'];
  if (envId != null && envId.trim().isNotEmpty) {
    return envId.trim();
  }
  return '${Platform.numberOfProcessors} nhân CPU';
}

/// Get total physical memory on Windows (e.g. "32 GB")
String getWindowsTotalPhysicalMemory() {
  try {
    final pointer = calloc<win32.MEMORYSTATUSEX>();
    pointer.ref.dwLength = sizeOf<win32.MEMORYSTATUSEX>();
    final result = win32.GlobalMemoryStatusEx(pointer);
    if (result != 0) {
      final totalBytes = pointer.ref.ullTotalPhys;
      calloc.free(pointer);
      final gb = (totalBytes / (1024 * 1024 * 1024)).round();
      return '$gb GB';
    }
    calloc.free(pointer);
  } catch (_) {}
  return '';
}
