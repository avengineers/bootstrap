import hashlib
from pathlib import Path

import pytest

from bootstrap import Executor


@pytest.mark.parametrize(
    "file_content",
    [
        "",
        "some content",
        "some other content",
        "some content\r\nwith Windows\r\nnewlines",
        "some content\nwith Unix\nnewlines",
    ],
)
def test_get_file_hash(tmp_path: Path, file_content: str):
    file = tmp_path / "some_file"

    # call item under test in case of non-existing file
    file_hash = Executor.get_file_hash(file)

    # check result
    assert not file.exists()
    assert file_hash == ""

    # create file as input
    file.write_text(file_content, newline="\n")

    # call item under test in case of non-existing file
    file_hash = Executor.get_file_hash(file)

    # check result
    assert file_hash == hashlib.sha256(file_content.encode()).hexdigest()
