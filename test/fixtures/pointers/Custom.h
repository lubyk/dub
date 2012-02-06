#ifndef POINTERS_CUSTOM_H_
#define POINTERS_CUSTOM_H_

#include <string>

/** This class is used to test:
 *   * get/set functions as attributes
 */
class Custom {
  std::string url_;
  double value_;
public:
  Custom(const std::string &url, double value)
    : url_(url)
    , value_(value)
  {}

  std::string getUrl() const {
    return std::string("/root/").append(url_);
  }

  void setUrl(const std::string &url) {
    url_ = url;
  }
};

class SubCustom : public Custom {
public:
  SubCustom(const std::string &url, double value)
    : Custom(url, value)
  {}
};
#endif // POINTERS_CUSTOM_H_

