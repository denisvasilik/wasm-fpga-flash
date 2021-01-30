import setuptools

with open("README.md", "r") as fh:
    long_description = fh.read()

__tag__ = ""
__build__ = 0
__version__ = "{}".format(__tag__)
__commit__ = "0000000"

setuptools.setup(
    name="wasm-fpga-flash",
    version=__version__,
    author="Denis Vasilìk",
    author_email="contact@denisvasilik.com",
    url="https://github.com/denisvasilik/wasm-fpga-flash/",
    project_urls={
        "Bug Tracker": "https://github.com/denisvasilik/wasm-fpga/",
        "Documentation": "https://wasm-fpga.readthedocs.io/en/latest/",
        "Source Code": "https://github.com/denisvasilik/wasm-fpga-flash/",
    },
    description="WebAssembly FPGA Flash",
    long_description=long_description,
    long_description_content_type="text/markdown",
    packages=setuptools.find_packages(),
    classifiers=[
        "Programming Language :: Python :: 3.6",
        "Operating System :: OS Independent",
    ],
    dependency_links=[],
    package_dir={},
    package_data={},
    data_files=[
        ("wasm-fpga-flash/package", ["package/component.xml"]),
        ("wasm-fpga-flash/package/bd", ["package/bd/bd.tcl"]),
        ("wasm-fpga-flash/package/xgui", ["package/xgui/wasm_fpga_flash_v1_0.tcl"]),
        (
            "wasm-fpga-stack/resources",
            [
                "resources/wasm_fpga_loader_header.vhd",
                "resources/wasm_fpga_engine_header.vhd",
                "resources/wasm_fpga_uart_header.vhd",
            ],
        ),
        ("wasm-fpga-flash/src",
            [
                "src/WasmFpgaFlash.vhd",
                "src/WasmFpgaFlashPackage.vhd",
            ],
        ),
        (
            "wasm-fpga-flash/tb",
            [
                "tb/tb_pkg_helper.vhd",
                "tb/tb_pkg.vhd",
                "tb/tb_std_logic_1164_additions.vhd",
                "tb/tb_Types.vhd",
                "tb/tb_FileIo.vhd",
                "tb/tb_WasmFpgaFlash.vhd",
            ],
        ),
        ("wasm-fpga-flash", ["CHANGELOG.md", "AUTHORS", "LICENSE"]),
    ],
    setup_requires=[],
    install_requires=[],
    entry_points={},
)
