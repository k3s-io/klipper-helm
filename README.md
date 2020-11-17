klipper-helm
========

_NOTE: this repository has been recently (2020-10-07) moved out of the github.com/rancher org to github.com/k3s-io
supporting the [acceptance of K3s as a CNCF sandbox project](https://github.com/cncf/toc/pull/447)_.

---

This is the image that run helm install/upgrade/remove for the
integrated helm support in klipper.  The approach is extremely
simple. This is just a single shell script.

## Building

`make`

## Contact

For bugs, questions, comments, corrections, suggestions, etc., open an issue in
[k3s-io/helm-controller](//github.com/k3s-io/helm-controller/issues).

## License
Copyright (c) 2019 [Rancher Labs, Inc.](http://rancher.com)

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

[http://www.apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0)

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
