import "sendbird_sfx.dart";
import 'package:sendbird_sdk/sendbird_sdk.dart';
export "sendbird_sfx.dart";

// Simple class that simply retains and passes commands
// to all subclasses of SendbirdSFX elements.
class SendbirdSFXController {
  SendbirdSFXController(this.specialEffects);

  List<SendbirdSFX> specialEffects;

  Future<void> checkAndTriggerAll(
    BaseChannel channel,
    List<BaseMessage> messages,
  ) async {
    for (BaseMessage message in messages) {
      await checkAndTrigger(channel, message);
    }
    return;
  }

  Future<void> checkAndTrigger(
    BaseChannel channel,
    BaseMessage message,
  ) async {
    for (SendbirdSFX sfx in specialEffects) {
      await sfx.checkAndTrigger(channel, message);
    }
    return;
  }

  Future<void> dispose() async {
    for (SendbirdSFX sfx in specialEffects) {
      sfx.dispose();
    }
    return;
  }
}
