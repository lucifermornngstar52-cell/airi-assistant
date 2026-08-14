#ifndef RUNNER_RUNNER_H_
#define RUNNER_RUNNER_H_

#include <flutter/flutter_engine.h>
#include <string>

class Runner {
 public:
  Runner(flutter::FlutterEngine* engine);
  
 private:
  void RegisterMethodChannels();
  flutter::FlutterEngine* engine_;
};

#endif  // RUNNER_RUNNER_H_
