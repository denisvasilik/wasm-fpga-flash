MICRON_MODEL_LINK=https://media-www.micron.com/-/media/client/global/documents/products/sim-model/nor-flash/serial/bfm/n25q/n25q128a13e_3v_micronxip_vg12,-d-,tar.gz
PWD=$(shell pwd)

all: package

prepare:
	@mkdir -p work
	@mkdir -p resources
	curl ${MICRON_MODEL_LINK} -o resources/n25q128a13e_3v_micronxip_vg12.tar.gz
	tar -xf resources/n25q128a13e_3v_micronxip_vg12.tar.gz -C ./tb
	patch tb/N25Q128A13E_VG12/code/N25Qxxx.v patches/0001-Fix-N25Qxxx-for-VHDL-simulation.patch
	sed -i "s,include/,,g" tb/N25Q128A13E_VG12/include/DevParam.h
	sed -i "s,include/,,g" tb/N25Q128A13E_VG12/include/Decoders.h

hxs: fetch-definitions


project: prepare
	@vivado -mode batch -source scripts/create_project.tcl -notrace -nojournal -tempDir work -log work/vivado.log

package:
	python3 setup.py sdist bdist_wheel

clean:
	@rm -rf .Xil vivado*.log vivado*.str vivado*.jou
	@rm -rf work \
		src-gen \
		resources \
		tb/N25Q128A13E_VG12

install-from-test-pypi:
	pip3 install --upgrade -i https://test.pypi.org/simple/ --extra-index-url https://pypi.org/simple wasm-fpga-control

upload-to-test-pypi: package
	python3 -m twine upload --repository-url https://test.pypi.org/legacy/ dist/*

upload-to-pypi: package
	python3 -m twine upload --repository pypi dist/*

.PHONY: all prepare project package clean fetch-definitions
