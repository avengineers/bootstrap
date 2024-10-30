from bootstrap import Version


def test_version_equality():
    assert Version("2.0.0") == Version("2.0.0")
    assert Version("1.1") == Version("1.1")

def test_version_inequality():
    assert Version("1.0.0") < Version("2.0.0")
    assert Version("1.0.0") <= Version("2.0.0")
    assert Version("2.0.0") > Version("1.9.9")
    assert Version("2.0.0") >= Version("1.0.0")
    assert Version("24.2") > Version("24.0") >= Version("22.2")
