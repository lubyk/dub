
#include "Owner.h"
#include "Pen.h"
// This is only required to monitor object destruction.
Owner::Owner(Pen * pen) : pen_(pen) {
  if (pen_) pen_->setOwner(this);
}

void Owner::own(Pen *pen) {
  pen_ = pen;
  pen_->setOwner(this);
}

Owner::~Owner() {
  if (pen_) {
    pen_->setOwner(NULL);
  }
}

void Owner::destroyPen() {
  if (pen_) {
    delete pen_;
    pen_ = NULL;
  }
}
