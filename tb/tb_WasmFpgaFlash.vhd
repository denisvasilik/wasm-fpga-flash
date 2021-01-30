library IEEE;
use IEEE.STD_LOGIC_1164.all;

use IEEE.NUMERIC_STD.all;

library work;
use work.tb_types.all;

entity tb_WasmFpgaFlash is
    generic (
        stimulus_path : string := "../../../../../simstm/";
        stimulus_file : string := "WasmFpgaFlash.stm"
    );
end;

architecture Behavioural of tb_WasmFpgaFlash is

    constant CLK100M_PERIOD : time := 10 ns;

    signal Clk100M : std_logic := '0';
    signal Rst : std_logic := '1';
    signal nRst : std_logic := '0';

    signal WasmFpgaFlash_FileIO : T_WasmFpgaFlash_FileIo;
    signal FileIO_WasmFpgaFlash : T_FileIO_WasmFpgaFlash;

    signal ModuleMemory_FileIO : T_ModuleMemory_FileIO;
    signal FileIO_ModuleMemory : T_FileIO_ModuleMemory;

    signal Module_Adr : std_logic_vector(23 downto 0);
    signal Module_Sel : std_logic_vector(3 downto 0);
    signal Module_We : std_logic;
    signal Module_Stb : std_logic;
    signal Module_DatOut : std_logic_vector(31 downto 0);
    signal Module_DatIn: std_logic_vector(31 downto 0);
    signal Module_Ack : std_logic;
    signal Module_Cyc : std_logic_vector(0 downto 0);

    signal ModuleMemory_Adr : std_logic_vector(23 downto 0);
    signal ModuleMemory_Sel : std_logic_vector(3 downto 0);
    signal ModuleMemory_We : std_logic;
    signal ModuleMemory_Stb : std_logic;
    signal ModuleMemory_DatOut : std_logic_vector(31 downto 0);
    signal ModuleMemory_DatIn: std_logic_vector(31 downto 0);
    signal ModuleMemory_Ack : std_logic;
    signal ModuleMemory_Cyc : std_logic_vector(0 downto 0);

    signal SpiFlash_MiSo : std_logic;
    signal SpiFlash_MoSi : std_logic;
    signal SpiFlash_SClk : std_logic;
    signal SpiFlash_CsNeg : std_logic;

    constant HOLD_DQ3 : std_logic := '1';
    constant Vpp_W_DQ2 : std_logic := '1';
    constant Vcc : std_logic_vector(31 downto 0) := x"00000BB8";

begin

    nRst <= not Rst;

    Clk100MGen : process is
    begin
        Clk100M <= not Clk100M;
        wait for CLK100M_PERIOD / 2;
    end process;

    RstGen : process is
    begin
        Rst <= '1';
        wait for 600000ns; -- SPI Flash Device is accessible after this time
        Rst <= '0';
        wait;
    end process;

    tb_FileIO_i : entity work.tb_FileIO
        generic map (
            stimulus_path => stimulus_path,
            stimulus_file => stimulus_file
        )
        port map (
            Clk => Clk100M,
            Rst => Rst,
            WasmFpgaFlash_FileIO => WasmFpgaFlash_FileIO,
            FileIO_WasmFpgaFlash => FileIO_WasmFpgaFlash,
            ModuleMemory_FileIO => ModuleMemory_FileIO,
            FileIO_ModuleMemory => FileIO_ModuleMemory
        );

    WasmFpgaFlash_i : entity work.WasmFpgaFlash
        port map (
            Clk => Clk100M,
            nRst => nRst,
            Loaded => WasmFpgaFlash_FileIO.Loaded,
            MiSo => SpiFlash_MiSo,
            MoSi => SpiFlash_MoSi,
            SClk => SpiFlash_SClk,
            CsNeg => SpiFlash_CsNeg,
            Module_Adr => Module_Adr,
            Module_Sel => Module_Sel,
            Module_We => Module_We,
            Module_Stb => Module_Stb,
            Module_DatOut => Module_DatIn,
            Module_DatIn => Module_DatOut,
            Module_Ack => Module_Ack,
            Module_Cyc => Module_Cyc
        );

    N25Q128A13E_i : entity work.N25Qxxx
        port map (
            S => SpiFlash_CsNeg,
            C => SpiFlash_SClk,
            HOLD_DQ3 => HOLD_DQ3,
            DQ0 => SpiFlash_MoSi,
            DQ1 => SpiFlash_MiSo,
            Vcc => Vcc,
            Vpp_W_DQ2 => Vpp_W_DQ2
        );

    -- File IO and WebAssembly engine can write to module memory
    ModuleMemory_Adr <= FileIO_ModuleMemory.Adr when FileIO_ModuleMemory.Cyc = "1" else Module_Adr;
    ModuleMemory_Sel <= FileIO_ModuleMemory.Sel when FileIO_ModuleMemory.Cyc = "1" else Module_Sel;
    ModuleMemory_We <= FileIO_ModuleMemory.We when FileIO_ModuleMemory.Cyc = "1" else Module_We;
    ModuleMemory_Stb <= FileIO_ModuleMemory.Stb when FileIO_ModuleMemory.Cyc = "1" else Module_Stb;
    ModuleMemory_DatIn <= FileIO_ModuleMemory.DatIn when FileIO_ModuleMemory.Cyc = "1" else Module_DatIn;
    ModuleMemory_Cyc <= FileIO_ModuleMemory.Cyc when FileIO_ModuleMemory.Cyc = "1" else Module_Cyc;

    ModuleMemory_FileIO.Ack <= ModuleMemory_Ack;
    ModuleMemory_FileIO.DatOut <= ModuleMemory_DatOut;

    Module_DatOut <= ModuleMemory_DatOut;
    Module_Ack <= ModuleMemory_Ack;

    ModuleMemory_i : entity work.WbRam
        port map (
            Clk => Clk100M,
            nRst => nRst,
            Adr => ModuleMemory_Adr,
            Sel => ModuleMemory_Sel,
            DatIn => ModuleMemory_DatIn,
            We => ModuleMemory_We,
            Stb => ModuleMemory_Stb,
            Cyc => ModuleMemory_Cyc,
            DatOut => ModuleMemory_DatOut,
            Ack => ModuleMemory_Ack
        );

end;