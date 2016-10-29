library chess3man.engine.move;

import 'pos.dart';
import 'state.dart';
import 'board.dart';
import 'possib.dart';
import 'dart:async';
import 'colors.dart';
import 'castling.dart';
import 'castlingcheck.dart';
import 'epstore.dart';
import 'prom.dart';

class Move {
  final Pos from;
  final Vector vec;
  final State before;
  const Move(this.from, this.vec, this.before);
  Pos get to => vec.addTo(from);
  Square get fromsq => before.board.gPos(from);
  Fig get what => fromsq.fig;
  Color get who => what.color;
  Square get tosq => before.board.gPos(to);
  Fig get alreadyThere => tosq.fig;
  Future<bool> possible() async {
    //TODO: Pos.correct?
    if (fromsq.empty) throw new NothingHereAlreadyError(this);
    if (what.color != before.movesnext)
      throw new ThatColorDoesNotMoveNowError(this, what.color);
    if (!(await possib(
        from,
        before.board,
        vec,
        before.moatsstate,
        before.enpassant,
        before.castling))) throw new ImpossibleMoveError(this);
    if (vec is PawnPromVector) {
      FigType toft = (vec as PawnPromVector).toft;
      switch (toft) {
        case FigType.zeroFigType:
        case FigType.king:
        case FigType.pawn:
          throw new IllegalPromotionError(this, toft);
      }
    }
    return true;
  }

  Future<State> after() async {
    assert(await possible());
    ColorCastling colorCastling = before.castling.give(who);
    if (what.type == FigType.king) colorCastling = ColorCastling.off;
    if (what.type == FigType.rook && from.rank == 0) {
      if (from.file == who.board * 8) colorCastling = colorCastling.offqs();
      if (from.file == who.board * 8 + 7) colorCastling = colorCastling.offks();
    }
    int halfMoveClock = (what.type == FigType.pawn || tosq.notEmpty)
        ? 0
        : before.halfmoveclock + 1;
    EnPassantStore enPassantStore = before.enpassant;
    if (vec is PawnLongJumpVector)
      enPassantStore = //TODO: avoid [as]
          enPassantStore.appeared((vec as PawnLongJumpVector).enpfield(from));
    else
      enPassantStore = enPassantStore.nothing();
    if ((vec is PawnVector) &&
        (!(vec is PawnPromVector)) &&
        (vec as PawnVector).reqProm(from.rank))
      throw new NeedsToBePromotedError(this);
  }
}

abstract class IllegalMoveError extends StateError {
  final Move m;
  IllegalMoveError(this.m, String msg) : super(msg);
}

class NothingHereAlreadyError extends IllegalMoveError {
  NothingHereAlreadyError(Move m)
      : super(m, "How do you move that which does not exist?");
}

class ThatColorDoesNotMoveNowError extends IllegalMoveError {
  final Color c;
  ThatColorDoesNotMoveNowError(Move m, this.c)
      : super(
            m,
            "That is not " +
                m.what.color.toString() +
                "'s move, but " +
                m.before.movesnext.toString() +
                "'s");
}

class ImpossibleMoveError extends IllegalMoveError {
  ImpossibleMoveError(Move m) : super(m, "Illegal/impossible move");
}

class IllegalPromotionError extends IllegalMoveError {
  final FigType to;
  IllegalPromotionError(Move m, FigType to)
      : this.to = to,
        super(m, "Illegal promotion to " + to.toString() + "!");
}

class NeedsToBePromotedError extends IllegalMoveError {
  NeedsToBePromotedError(Move m) : super(m, "Promotion is obligatory!");
}