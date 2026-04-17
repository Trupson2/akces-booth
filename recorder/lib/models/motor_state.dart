enum Direction { clockwise, counterClockwise }

extension DirectionX on Direction {
  String get label => this == Direction.clockwise ? 'CW' : 'CCW';
  String get fullLabel =>
      this == Direction.clockwise ? 'Zgodnie' : 'Przeciwnie';
  Direction get flipped => this == Direction.clockwise
      ? Direction.counterClockwise
      : Direction.clockwise;
}

class MotorState {
  static const int minSpeed = 1;
  // ChackTok UI ma max 8. Na eventach weselnych zalecane 3-5 zeby goscie
  // sie nie zachwiali.
  static const int maxSpeed = 8;

  final bool connected;
  final bool running;
  final int speed;
  final Direction direction;

  const MotorState({
    required this.connected,
    required this.running,
    required this.speed,
    required this.direction,
  });

  const MotorState.initial()
      : connected = false,
        running = false,
        speed = 5,
        direction = Direction.clockwise;

  MotorState copyWith({
    bool? connected,
    bool? running,
    int? speed,
    Direction? direction,
  }) {
    return MotorState(
      connected: connected ?? this.connected,
      running: running ?? this.running,
      speed: speed ?? this.speed,
      direction: direction ?? this.direction,
    );
  }
}
