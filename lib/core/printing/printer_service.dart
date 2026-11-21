import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../db/app_database.dart';
import '../settings/shop_profile.dart';
import '../../features/inventory/domain/product_model.dart';
import 'escpos.dart';
import 'paper_width.dart';

export 'paper_width.dart';

enum PrinterConnectionStatus { disconnected, scanning, connecting, connected, error }

class BluetoothDeviceModel {
  final String name;
  final String address;

  const BluetoothDeviceModel({required this.name, required this.address});
}

class PrinterState {
  final PrinterConnectionStatus status;
  final BluetoothDeviceModel? connectedDevice;

  /// Printer remembered from last time (reconnected automatically when printing).
  final BluetoothDeviceModel? savedDevice;
  final PaperWidth paperWidth;
  final String? errorMessage;
  final List<BluetoothDeviceModel> availableDevices;
  final bool isPrinting;

  const PrinterState({
    this.status = PrinterConnectionStatus.disconnected,
    this.connectedDevice,
    this.savedDevice,
    this.paperWidth = PaperWidth.mm58,
    this.errorMessage,
    this.availableDevices = const [],
    this.isPrinting = false,
  });

  PrinterState copyWith({
    PrinterConnectionStatus? status,
    BluetoothDeviceModel? connectedDevice,
    bool clearConnected = false,
    BluetoothDeviceModel? savedDevice,
    PaperWidth? paperWidth,
    String? errorMessage,
    List<BluetoothDeviceModel>? availableDevices,
    bool? isPrinting,
  }) {
    return PrinterState(
      status: status ?? this.status,
      connectedDevice: clearConnected ? null : (connectedDevice ?? this.connectedDevice),
      savedDevice: savedDevice ?? this.savedDevice,
      paperWidth: paperWidth ?? this.paperWidth,
      errorMessage: errorMessage,
      availableDevices: availableDevices ?? this.availableDevices,
      isPrinting: isPrinting ?? this.isPrinting,
    );
  }
}

final printerProvider = StateNotifierProvider<PrinterService, PrinterState>((ref) {
  final service = PrinterService(ref.watch(databaseProvider));
  // Keep paper width in sync with the saved shop profile.
  ref.listen<AsyncValue<ShopProfile>>(
    shopProfileProvider,
    (_, next) => next.whenData((profile) => service.setPaperWidth(profile.paperWidth)),
    fireImmediately: true,
  );
  return service;
});

/// Prints to paired Bluetooth (classic / SPP) ESC/POS thermal printers on Android.
///
/// All messages are in simple Hindi because they are shown directly to the shopkeeper.
class PrinterService extends StateNotifier<PrinterState> {
  final AppDatabase _db;

  PrinterService(this._db) : super(const PrinterState()) {
    _loadSavedPrinter();
  }

  bool get _supported => !kIsWeb && Platform.isAndroid;

  Future<void> _loadSavedPrinter() async {
    try {
      final s = await _db.getAllSettings();
      final mac = s[SettingKeys.printerMac];
      if (mac != null && mac.isNotEmpty && mounted) {
        state = state.copyWith(
          savedDevice: BluetoothDeviceModel(name: s[SettingKeys.printerName] ?? 'Printer', address: mac),
        );
      }
    } catch (_) {}
  }

  void setPaperWidth(PaperWidth width) {
    if (!mounted) return;
    state = state.copyWith(paperWidth: width);
  }

  Future<String?> _ensureReady() async {
    if (!_supported) return 'प्रिंटर सिर्फ़ Android फ़ोन पर चलता है';
    final statuses = await [Permission.bluetoothConnect, Permission.bluetoothScan].request();
    if (statuses.values.any((s) => s.isPermanentlyDenied)) {
      return 'ब्लूटूथ की अनुमति बंद है। फ़ोन सेटिंग → ऐप्स → Kirana Store → अनुमति में चालू करें';
    }
    if (statuses.values.any((s) => !s.isGranted && !s.isLimited)) {
      return 'प्रिंटर के लिए ब्लूटूथ की अनुमति दें';
    }
    if (!await PrintBluetoothThermal.bluetoothEnabled) {
      return 'फ़ोन का ब्लूटूथ चालू करें';
    }
    return null;
  }

  /// Lists printers already paired in the phone's Bluetooth settings.
  Future<void> scanDevices() async {
    state = state.copyWith(status: PrinterConnectionStatus.scanning);
    final problem = await _ensureReady();
    if (problem != null) {
      state = state.copyWith(status: PrinterConnectionStatus.error, errorMessage: problem);
      return;
    }
    try {
      final paired = await PrintBluetoothThermal.pairedBluetooths;
      final devices = paired.map((d) => BluetoothDeviceModel(name: d.name, address: d.macAdress)).toList();
      final connected = await PrintBluetoothThermal.connectionStatus;
      state = state.copyWith(
        status: connected ? PrinterConnectionStatus.connected : PrinterConnectionStatus.disconnected,
        availableDevices: devices,
        errorMessage: devices.isEmpty ? 'कोई प्रिंटर नहीं मिला। पहले फ़ोन की ब्लूटूथ सेटिंग में प्रिंटर पेयर करें' : null,
      );
    } catch (e) {
      state = state.copyWith(status: PrinterConnectionStatus.error, errorMessage: 'प्रिंटर सूची नहीं मिली: $e');
    }
  }

  Future<bool> connect(BluetoothDeviceModel device) async {
    state = state.copyWith(status: PrinterConnectionStatus.connecting);
    final problem = await _ensureReady();
    if (problem != null) {
      state = state.copyWith(status: PrinterConnectionStatus.error, errorMessage: problem);
      return false;
    }
    try {
      if (await PrintBluetoothThermal.connectionStatus) {
        await PrintBluetoothThermal.disconnect;
      }
      final ok = await PrintBluetoothThermal.connect(macPrinterAddress: device.address);
      if (!ok) {
        state = state.copyWith(
          status: PrinterConnectionStatus.error,
          clearConnected: true,
          errorMessage: 'प्रिंटर से नहीं जुड़ पाए। प्रिंटर चालू है? पास रखें और फिर कोशिश करें',
        );
        return false;
      }
      await _db.upsertSettings({SettingKeys.printerMac: device.address, SettingKeys.printerName: device.name});
      state = state.copyWith(status: PrinterConnectionStatus.connected, connectedDevice: device, savedDevice: device);
      return true;
    } catch (e) {
      state = state.copyWith(status: PrinterConnectionStatus.error, errorMessage: 'प्रिंटर से जुड़ने में दिक्कत: $e');
      return false;
    }
  }

  Future<void> disconnect() async {
    if (_supported) {
      try {
        await PrintBluetoothThermal.disconnect;
      } catch (_) {}
    }
    state = state.copyWith(status: PrinterConnectionStatus.disconnected, clearConnected: true);
  }

  /// Connects to the remembered printer if needed. Returns an error message or null.
  Future<String?> _ensureConnected() async {
    final problem = await _ensureReady();
    if (problem != null) return problem;
    if (await PrintBluetoothThermal.connectionStatus) return null;
    final target = state.connectedDevice ?? state.savedDevice;
    if (target == null) return 'पहले सेटिंग में प्रिंटर चुनें';
    final ok = await connect(target);
    return ok ? null : (state.errorMessage ?? 'प्रिंटर से नहीं जुड़ पाए');
  }

  Future<String?> _send(List<int> bytes) async {
    final problem = await _ensureConnected();
    if (problem != null) return problem;
    final ok = await PrintBluetoothThermal.writeBytes(bytes);
    return ok ? null : 'प्रिंटर तक डेटा नहीं पहुँचा। फिर से कोशिश करें';
  }

  /// Renders the widget inside [repaintKey] at printer resolution and prints it.
  /// Returns null on success, otherwise a Hindi error message.
  Future<String?> printReceipt({required GlobalKey repaintKey, int copies = 1}) async {
    if (state.isPrinting) return 'प्रिंट पहले से चल रहा है';
    state = state.copyWith(isPrinting: true);
    try {
      final raster = await captureForPrinter(repaintKey, state.paperWidth);
      if (raster == null) return 'रसीद की तस्वीर नहीं बन पाई';
      final bytes = <int>[...EscPos.init, ...EscPos.alignCenter];
      for (var i = 0; i < copies; i++) {
        bytes
          ..addAll(raster)
          ..addAll(EscPos.feedLines(3))
          ..addAll(EscPos.cut);
      }
      return await _send(bytes);
    } catch (e) {
      return 'प्रिंटर में दिक्कत: $e';
    } finally {
      if (mounted) state = state.copyWith(isPrinting: false);
    }
  }

  Future<String?> printTestPage(String shopName) async {
    final bytes = <int>[
      ...EscPos.init,
      ...EscPos.alignCenter,
      ...EscPos.textLine('*** TEST PRINT ***'),
      ...EscPos.textLine(shopName),
      ...EscPos.textLine('Printer OK - ${state.paperWidth == PaperWidth.mm58 ? "58mm" : "80mm"}'),
      ...EscPos.textLine('--------------------------------'),
      ...EscPos.feedLines(3),
      ...EscPos.cut,
    ];
    return _send(bytes);
  }

  /// Captures a RepaintBoundary scaled so its width equals the printer's dot width.
  static Future<List<int>?> captureForPrinter(GlobalKey boundaryKey, PaperWidth paper) async {
    final boundary = boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null || boundary.size.width <= 0) return null;
    final ratio = paper.dots / boundary.size.width;
    final ui.Image image = await boundary.toImage(pixelRatio: ratio);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
      if (data == null) return null;
      // Rounding can make the image a pixel wider than the print head; crop the excess.
      final width = image.width > paper.dots ? paper.dots : image.width;
      return EscPos.rasterImage(
        width: width,
        stride: image.width,
        height: image.height,
        rgba: data.buffer.asUint8List(),
      );
    } finally {
      image.dispose();
    }
  }
}
