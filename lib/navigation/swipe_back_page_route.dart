import 'package:flutter/cupertino.dart';

/// A customer-facing page route with the native iOS leading-edge back gesture.
class SwipeBackPageRoute<T> extends CupertinoPageRoute<T> {
  SwipeBackPageRoute({required super.builder, super.settings});
}
