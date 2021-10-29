import 'package:flutter/material.dart';
import 'package:sendbird_sdk/sendbird_sdk.dart';
import 'dart:async';

// Base class for keyword triggered animation effects from Sendbird chat callbacks
class SendbirdSFX {
  SendbirdSFX(
      {required this.metaKey,
      required this.caselessKeywords,
      this.expiresIn = const Duration(
          days:
              1), // Set a ludicrous duration if you don't want to use a timeout.
      this.showToSender = false,
      this.debugCallback});

  String metaKey; // unique messageMetaArray key for this special effect (sfx)
  List<String> caselessKeywords =
      []; // List of string keywords that trigger this sfx
  Duration
      expiresIn; // How old a message with target keywords can be before ignoring
  bool showToSender; // Should we display effect to the sender, too
  Function(String message)?
      debugCallback; // If you want to readout what's going on without setting breakpoints.

  // UI element unique to the special effect.
  // This will likely be added to a Stack object
  // from the calling screen.
  Widget ui() {
    return Container();
  }

  Future<void> checkAndTrigger(BaseChannel channel, BaseMessage message) async {
    // See if this incoming message contains any target keywords
    if (shouldTrigger(
          channel,
          message,
          expiresIn,
          showToSender,
          caselessKeywords,
        ) ==
        false) {
      return;
    }

    // It is worthy - Play effect
    play();

    // Let's mark it as having triggered action for the user
    await markRead(channel, message);

    // Stop effect from possibly repeating
    stop();
  }

  Future<void> markRead(
    BaseChannel channel,
    BaseMessage message,
  ) async {
    String? uid = SendbirdSdk().currentUser?.userId;
    if (uid == null) {
      debugCallback
          ?.call("SendbirdSFX $metaKey: markRead: no current Sendbird user");
      return;
    }
    BaseMessage updatedMessage = await channel.addMessageMetaArray(message, [
      MessageMetaArray(key: metaKey, value: [uid])
    ]);
    debugCallback?.call(
        "SendbirdSFX $metaKey: markRead: updated message: `${updatedMessage.message}`: metaArray: ${updatedMessage.getMetaArrays([
          metaKey
        ])[0].value}");
  }

  // Check if special effect should trigger
  bool shouldTrigger(
    BaseChannel channel,
    BaseMessage message,
    Duration? timeout,
    bool showSender,
    List<String> caselessKeywords,
  ) {
    User? sbUser = SendbirdSdk().currentUser;
    if (sbUser == null) {
      // Well this is odd, how come we don't know the current user by now?
      throw Exception("Current Sendbird user unknown");
    }

    // Ignore if sender is the current user
    if (showSender == false &&
        message.sender != null &&
        message.sender!.isCurrentUser) {
      return false;
    }

    // Does message contain target word(s)
    bool containsKeywords =
        stringContainsOneOf(caselessKeywords, message.message);
    if (containsKeywords == false) {
      return false;
    }

    // Are we past caring about this effect trigger
    DateTime messageDT = DateTime.fromMillisecondsSinceEpoch(message.createdAt);
    Duration messageAge = DateTime.now().difference(messageDT);
    if (timeout != null && messageAge > timeout) {
      return false;
    }

    // If effect has already been displayed for this message - bail
    if (alreadyDisplayedFor(message, metaKey, sbUser.userId)) {
      return false;
    }
    return true;
  }

  // Override if you want to change how to check for substrings or
  // target keywords
  bool stringContainsOneOf(List<String> keywords, String string,
      {bool caseSensitive = false}) {
    for (String keyword in keywords) {
      // Is keyword in message
      RegExp exp = RegExp(
        "\\b" + keyword + "\\b",
        caseSensitive: caseSensitive,
      );
      bool match = exp.hasMatch(string);
      // Return true if any of the target keywords are in the given string
      if (match == true) {
        return true;
      }
    }
    return false;
  }

  bool alreadyDisplayedFor(
    BaseMessage message,
    String key,
    String userId,
  ) {
    List<MessageMetaArray> arrays = message.getMetaArrays([key]);

    // Pre-existing meta record not recorded - message has
    if (arrays.isEmpty == true) {
      debugCallback?.call(
          "SendbirdSFX $metaKey: alreadyDisplayedFor: message: `${message.message}`: metaArray is empty for key $metaKey");
      return false;
    }

    debugCallback?.call(
        "SendbirdSFX $metaKey: alreadyDisplayedFor: message: `${message.message}`: metaArray: ${message.getMetaArrays([
          metaKey
        ])[0].value}");

    MessageMetaArray array = arrays[0];
    return array.value.contains(userId);
  }

  // Play the special effect
  void play() {}

  // Stop the special effect
  void stop() {}

  // Override to do any cleanup
  void dispose() {}
}
