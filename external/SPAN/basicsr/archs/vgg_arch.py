from torch import nn


class VGGFeatureExtractor(nn.Module):
    """Compatibility stub for SPAN's L1-only training config.

    The official SPAN release uses BasicSR loss registration, which imports the
    VGG perceptual loss helper even when the active config only uses L1 loss.
    This project does not enable perceptual loss for FPGA-oriented training.
    """

    def __init__(self, *args, **kwargs):
        super().__init__()
        raise NotImplementedError("VGGFeatureExtractor is not included in this SPAN training setup.")
