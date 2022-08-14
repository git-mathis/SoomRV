VERILATOR_FLAGS = --cc --trace-structs --build --trace


decoder_tb:
	verilator $(VERILATOR_FLAGS) --exe Decode_tb.cpp --top-module Decode src/Include.sv src/InstrDecoder.sv src/RAT.sv src/Decode.sv src/ReservationStation.sv src/IntALU.sv src/ROB.sv src/ProgramCounter.sv

clean:
	rm -r obj_dir