import 'dart:typed_data';

/// Assetto Corsa UDP ハンドシェイクパケット（12バイト）
class ACHandshaker {
  static const int operationConnect = 0;
  static const int operationCarInfo = 1;
  static const int operationLapInfo = 2;
  static const int operationDisconnect = 3;

  final int identifier;
  final int version;
  final int operationId;

  const ACHandshaker(
    this.operationId, {
    this.identifier = 1,
    this.version = 1,
  });

  Uint8List toBytes() {
    final data = ByteData(12);
    data.setUint32(0, identifier, Endian.little);
    data.setUint32(4, version, Endian.little);
    data.setUint32(8, operationId, Endian.little);
    return data.buffer.asUint8List();
  }
}

/// Assetto Corsa RTCarInfo パケット（328バイト）
class RTCarInfo {
  final double speedKmh;
  final double engineRPM;
  final int gear;
  final double gas;
  final double brake;
  final int lapTime;

  const RTCarInfo({
    this.speedKmh = 0,
    this.engineRPM = 0,
    this.gear = 0,
    this.gas = 0,
    this.brake = 0,
    this.lapTime = 0,
  });

  factory RTCarInfo.fromBytes(Uint8List bytes) {
    if (bytes.length < 328) {
      throw Exception('Invalid RTCarInfo size: ${bytes.length}');
    }
    final data = ByteData.sublistView(bytes);
    return RTCarInfo(
      speedKmh: data.getFloat32(8, Endian.little),
      engineRPM: data.getFloat32(68, Endian.little),
      gear: data.getUint32(76, Endian.little),
      gas: data.getFloat32(56, Endian.little),
      brake: data.getFloat32(60, Endian.little),
      lapTime: data.getUint32(40, Endian.little),
    );
  }
}
