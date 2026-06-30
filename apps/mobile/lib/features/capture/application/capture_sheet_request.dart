import 'package:flutter_riverpod/flutter_riverpod.dart';

final captureSheetRequestProvider =
    StateNotifierProvider<CaptureSheetRequestController, CaptureSheetRequest>(
      (ref) => CaptureSheetRequestController(),
    );

class CaptureSheetRequest {
  const CaptureSheetRequest({required this.requestId, required this.handledId});

  const CaptureSheetRequest.initial() : requestId = 0, handledId = 0;

  final int requestId;
  final int handledId;

  bool get hasPending => requestId > handledId;

  CaptureSheetRequest copyWith({int? requestId, int? handledId}) {
    return CaptureSheetRequest(
      requestId: requestId ?? this.requestId,
      handledId: handledId ?? this.handledId,
    );
  }
}

class CaptureSheetRequestController extends StateNotifier<CaptureSheetRequest> {
  CaptureSheetRequestController() : super(const CaptureSheetRequest.initial());

  void request() {
    state = state.copyWith(requestId: state.requestId + 1);
  }

  void markHandled(int requestId) {
    if (requestId <= state.handledId) {
      return;
    }
    state = state.copyWith(handledId: requestId);
  }
}
