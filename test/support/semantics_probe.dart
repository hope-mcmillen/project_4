import 'package:flutter/rendering.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

/// One node of the accessibility tree as a screen reader would meet it.
class Spoken {
  const Spoken(this.id, this.label, this.isLiveRegion);
  final int id;
  final String label;
  final bool isLiveRegion;

  @override
  String toString() => '#$id "$label"${isLiveRegion ? ' [live]' : ''}';
}

/// Every node a screen reader can land on: the tree's own nodes, with the
/// text of anything merged into them already folded into the label.
List<Spoken> spokenNodes(WidgetTester tester) {
  final found = <Spoken>[];
  void visit(SemanticsNode node) {
    if (!node.isMergedIntoParent) {
      final data = node.getSemanticsData();
      found.add(Spoken(node.id, data.label, data.flagsCollection.isLiveRegion));
    }
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  for (final view in tester.binding.renderViews) {
    final root = view.owner?.semanticsOwner?.rootSemanticsNode;
    if (root != null) visit(root);
  }
  return found;
}

/// Watches the accessibility tree between frames and records what a platform
/// screen reader would announce on its own: a live-region node that appears,
/// or whose label changes, or that only now becomes a live region.
///
/// Nothing is recorded for a node that is not a live region, however often
/// its label changes; that is what keeps a per-second clock silent.
class AnnouncementLog {
  AnnouncementLog(this._tester) {
    sample();
  }

  final WidgetTester _tester;

  /// Labels announced so far, in order.
  final announced = <String>[];

  final _lastLive = <int, String>{};

  /// Call after every frame that may have changed the tree.
  void sample() {
    final live = <int, String>{
      for (final node in spokenNodes(_tester))
        if (node.isLiveRegion) node.id: node.label,
    };
    live.forEach((id, label) {
      if (_lastLive[id] != label) announced.add(label);
    });
    _lastLive
      ..clear()
      ..addAll(live);
  }

  /// Advances the fake clock one second per frame, as a running app does,
  /// sampling after each; one big pump would fold many ticks into one frame
  /// and hide an announcement per tick.
  Future<void> pumpSeconds(int seconds) async {
    for (var i = 0; i < seconds; i++) {
      await _tester.pump(const Duration(seconds: 1));
      sample();
    }
  }
}
