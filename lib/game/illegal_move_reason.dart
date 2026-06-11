enum IllegalMoveReason {
  occupied,
  ko,
  suicide,
}

String illegalMoveToastMessage(IllegalMoveReason reason) {
  return switch (reason) {
    IllegalMoveReason.occupied => '該點已有棋子',
    IllegalMoveReason.ko => '打劫，不能立即回提',
    IllegalMoveReason.suicide => '該手無氣，不能落子',
  };
}
