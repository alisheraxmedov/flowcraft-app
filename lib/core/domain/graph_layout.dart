import 'dart:math' as math;
import 'dart:ui';

/// Which way a laid-out graph flows: top-to-bottom, left-to-right and their
/// reverses.
enum LayoutDirection { tb, lr, bt, rl }

/// Sugiyama-lite layered layout: break cycles, rank by longest path, order
/// each rank by barycenter sweeps, then pack ranks with fixed gaps.
///
/// Pure and deterministic — same input, same output; siblings keep their
/// insertion order unless a crossing-reducing sweep has a reason to move
/// them. Knows nothing about elements or MCP, only ids, sizes and edges.
class GraphLayout {
  GraphLayout._();

  static const int _sweeps = 4;

  /// Top-left position of every id in [ids].
  ///
  /// Edges naming unknown ids and self-loops are ignored — validating them
  /// is the caller's job at the trust boundary. Isolated nodes land on
  /// rank 0.
  // ponytail: no dummy nodes, so an edge spanning several ranks is drawn
  // straight and may cross boxes in between; add virtual nodes if that bites.
  static Map<String, Offset> layout({
    required List<String> ids,
    required Map<String, Size> sizes,
    required List<(String from, String to)> edges,
    LayoutDirection direction = LayoutDirection.tb,
    double nodeGap = 48,
    double rankGap = 96,
  }) {
    final n = ids.length;
    final index = {for (var i = 0; i < n; i++) ids[i]: i};
    final out = List.generate(n, (_) => <int>[]);
    for (final (from, to) in edges) {
      final a = index[from], b = index[to];
      if (a == null || b == null || a == b) continue;
      out[a].add(b);
    }

    // Cycle breaking: a DFS back edge (target still on the stack) is
    // reversed, for ranking only.
    final dag = List.generate(n, (_) => <int>[]);
    final state = List.filled(n, 0); // 0 new, 1 on stack, 2 done
    // Iterative (explicit stack): a chain of 10k nodes would otherwise
    // recurse 10k deep.
    final next = List.filled(n, 0); // next out-edge to try, per node
    void visit(int root) {
      final stack = [root];
      state[root] = 1;
      while (stack.isNotEmpty) {
        final u = stack.last;
        if (next[u] == out[u].length) {
          state[u] = 2;
          stack.removeLast();
          continue;
        }
        final v = out[u][next[u]++];
        if (state[v] == 1) {
          dag[v].add(u);
        } else {
          dag[u].add(v);
          if (state[v] == 0) {
            state[v] = 1;
            stack.add(v);
          }
        }
      }
    }

    for (var i = 0; i < n; i++) {
      if (state[i] == 0) visit(i);
    }

    // Longest-path layering via Kahn: rank = 1 + max rank of predecessors.
    final inDeg = List.filled(n, 0);
    for (final targets in dag) {
      for (final v in targets) {
        inDeg[v]++;
      }
    }
    final rank = List.filled(n, 0);
    final queue = [
      for (var i = 0; i < n; i++)
        if (inDeg[i] == 0) i,
    ];
    for (var head = 0; head < queue.length; head++) {
      final u = queue[head];
      for (final v in dag[u]) {
        rank[v] = math.max(rank[v], rank[u] + 1);
        if (--inDeg[v] == 0) queue.add(v);
      }
    }

    final rankCount = n == 0 ? 0 : rank.reduce(math.max) + 1;
    final ranks = List.generate(rankCount, (_) => <int>[]);
    for (var i = 0; i < n; i++) {
      ranks[rank[i]].add(i);
    }

    // Barycenter sweeps over the (acyclic) ranking edges.
    final preds = List.generate(n, (_) => <int>[]);
    for (var u = 0; u < n; u++) {
      for (final v in dag[u]) {
        preds[v].add(u);
      }
    }
    final pos = List.filled(n, 0);
    void reindex(List<int> r) {
      for (var k = 0; k < r.length; k++) {
        pos[r[k]] = k;
      }
    }

    ranks.forEach(reindex);
    void sweep(List<int> r, List<List<int>> neighbours) {
      double bary(int v) {
        final nb = neighbours[v];
        if (nb.isEmpty) return pos[v].toDouble();
        return nb.map((u) => pos[u]).reduce((a, b) => a + b) / nb.length;
      }

      final keys = {for (final v in r) v: bary(v)};
      // List.sort is not stable; the position tiebreak keeps it so.
      r.sort((a, b) {
        final c = keys[a]!.compareTo(keys[b]!);
        return c != 0 ? c : pos[a].compareTo(pos[b]);
      });
      reindex(r);
    }

    for (var s = 0; s < _sweeps; s++) {
      if (s.isEven) {
        for (var r = 1; r < rankCount; r++) {
          sweep(ranks[r], preds);
        }
      } else {
        for (var r = rankCount - 2; r >= 0; r--) {
          sweep(ranks[r], dag);
        }
      }
    }

    // Packing in abstract axes: `along` runs inside a rank, `across` between
    // ranks. LR/RL swap which of width/height each one is.
    final horizontal =
        direction == LayoutDirection.lr || direction == LayoutDirection.rl;
    double alongOf(int i) {
      final s = sizes[ids[i]]!;
      return horizontal ? s.height : s.width;
    }

    double acrossOf(int i) {
      final s = sizes[ids[i]]!;
      return horizontal ? s.width : s.height;
    }

    final totals = [
      for (final r in ranks)
        r.fold<double>(0, (sum, i) => sum + alongOf(i)) +
            nodeGap * math.max(0, r.length - 1),
    ];
    final widest = totals.isEmpty ? 0.0 : totals.reduce(math.max);
    final thickness = [
      for (final r in ranks)
        r.fold<double>(0, (m, i) => math.max(m, acrossOf(i))),
    ];
    final span =
        thickness.fold<double>(0, (a, b) => a + b) +
        rankGap * math.max(0, rankCount - 1);
    final flip =
        direction == LayoutDirection.bt || direction == LayoutDirection.rl;

    final result = <String, Offset>{};
    var across = 0.0;
    for (var r = 0; r < rankCount; r++) {
      var along = (widest - totals[r]) / 2;
      for (final i in ranks[r]) {
        // Centre each node inside its rank's thickness.
        var a = across + (thickness[r] - acrossOf(i)) / 2;
        if (flip) a = span - a - acrossOf(i);
        result[ids[i]] = horizontal ? Offset(a, along) : Offset(along, a);
        along += alongOf(i) + nodeGap;
      }
      across += thickness[r] + rankGap;
    }
    return result;
  }
}
