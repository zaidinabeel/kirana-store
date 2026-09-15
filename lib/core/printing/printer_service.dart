import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum PrinterConnectionStatus { disconnected, scanning, connecting, connected, error }
enum PaperWidth { mm58, mm80 }

extension PaperWidthExt on PaperWidth {
  String get label => this == PaperWidth.mm58 ? '58mm (Receipt)' : '80mm (Wide)';
  double get pixelWidth => this == PaperWidth.mm58 ? 384.0 : 576.0;
}

class BluetoothDeviceModel {
  final String name;
  final String address;
  final bool isConnected;

  BluetoothDeviceModel({
    required this.name,
    required this.address,
    this.isConnected = false,
  });
}

class PrinterState {
  final PrinterConnectionStatus status;
  final BluetoothDeviceModel? connectedDevice;
  final PaperWidth paperWidth;
  final String? errorMessage;
  final List<BluetoothDeviceModel> availableDevices;
  final bool isPrinting;

  PrinterState({
    this.status = PrinterConnectionStatus.connected,
    this.connectedDevice,
    this.paperWidth = PaperWidth.mm58,
    this.errorMessage,
    this.availableDevices = const [],
    this.isPrinting = false,
  });

  PrinterState copyWith({
    PrinterConnectionStatus? status,
    BluetoothDeviceModel? connectedDevice,
    PaperWidth? paperWidth,
    String? errorMessage,
    List<BluetoothDeviceModel>? availableDevices,
    bool? isPrinting,
  }) {
    return PrinterState(
      status: status ?? this.status,
      connectedDevice: connectedDevice ?? this.connectedDevice,
      paperWidth: paperWidth ?? this.paperWidth,
      errorMessage: errorMessage,
      availableDevices: availableDevices ?? this.availableDevices,
      isPrinting: isPrinting ?? this.isPrinting,
    );
  }
}

final printerProvider = StateNotifierProvider<PrinterService, PrinterState>((ref) {
  return PrinterService();
});

class PrinterService extends StateNotifier<PrinterState> {
  PrinterService()
      : super(PrinterState(
          status: PrinterConnectionStatus.connected,
          connectedDevice: BluetoothDeviceModel(
            name: 'MPT-II Thermal Printer (Bluetooth)',
            address: '00:11:22:33:44:55',
            isConnected: true,
          ),
          availableDevices: [
            BluetoothDeviceModel(
              name: 'MPT-II Thermal Printer (Bluetooth)',
              address: '00:11:22:33:44:55',
              isConnected: true,
            ),
            BluetoothDeviceModel(
              name: 'Everycom EC-58 POS',
              address: '66:77:88:99:AA:BB',
            ),
            BluetoothDeviceModel(
              name: 'TVS RP-3150 Star',
              address: 'CC:DD:EE:FF:00:11',
            ),
          ],
        ));

  void setPaperWidth(PaperWidth width) {
    state = state.copyWith(paperWidth: width);
  }

  Future<void> scanDevices() async {
    state = state.copyWith(status: PrinterConnectionStatus.scanning);
    await Future.delayed(const Duration(milliseconds: 1200));
    state = state.copyWith(
      status: state.connectedDevice != null
          ? PrinterConnectionStatus.connected
          : PrinterConnectionStatus.disconnected,
    );
  }

  Future<void> connect(BluetoothDeviceModel device) async {
    state = state.copyWith(status: PrinterConnectionStatus.connecting);
    await Future.delayed(const Duration(milliseconds: 1000));
    state = state.copyWith(
      status: PrinterConnectionStatus.connected,
      connectedDevice: BluetoothDeviceModel(
        name: device.name,
        address: device.address,
        isConnected: true,
      ),
    );
  }

  Future<void> disconnect() async {
    state = state.copyWith(
      status: PrinterConnectionStatus.disconnected,
      connectedDevice: null,
    );
  }

  /// Converts a RenderRepaintBoundary widget into bitmap raster bytes for ESC/POS printing
  static Future<Uint8List?> captureWidgetToImage(GlobalKey boundaryKey) async {
    try {
      final boundary = boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Error capturing receipt image: $e');
      return null;
    }
  }

  /// Print receipt bitmap raster image over Bluetooth ESC/POS queue
  Future<bool> printReceiptBitmap({
    required GlobalKey repaintKey,
    VoidCallback? onProgress,
  }) async {
    state = state.copyWith(isPrinting: true);
    try {
      final imageBytes = await captureWidgetToImage(repaintKey);
      if (imageBytes == null) {
        state = state.copyWith(
          isPrinting: false,
          errorMessage: 'Could not capture receipt preview',
        );
        return false;
      }

      // Simulate sending raster chunks to ESC/POS printer
      await Future.delayed(const Duration(milliseconds: 1200));

      state = state.copyWith(isPrinting: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isPrinting: false,
        errorMessage: 'Printer communication error: $e',
      );
      return false;
    }
  }
}
