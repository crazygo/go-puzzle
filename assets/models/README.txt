Place the local KataGo ONNX model file here as:

katago-kata1-b18c384nbt-batched-fp16.onnx

This file is downloaded by:

bash /home/runner/work/go-puzzle/go-puzzle/scripts/init-dev.sh

It is intentionally git-ignored and should not be committed to the repo.

The current Kaya/KataGo ONNX model uses dynamic board height and width axes, so
the same model asset is used for supported board sizes instead of maintaining
separate 9x9, 13x13, and 19x19 aliases.

The local Capture5 model files are:

capture5_13x13_11p_resnet_phase_g_tactical005_expected.onnx
capture5_13x13_11p_resnet_phase_g_tactical005_expected.metadata.json

It is a 13x13 capture-five policy model using feature schema
capture5_features_11p_ladder_v1 with 11 input planes. Expected ONNX SHA-256:

981dedf63f6b5fae567bbc354c340abafd4b1eec302858a27ec7c9d384343c54

This ONNX file is also intentionally git-ignored. Until it is published as a
release asset, copy it locally from:

/Users/admin/Code/go-puzzle-ml/models/generated/capture5_13x13_11p_resnet_phase_g_tactical005_expected.onnx
