library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity WasmFpgaFlash is
    port (
        Clk : in std_logic;
        nRst : in std_logic;
        Loaded : out std_logic;
        MiSo : in std_logic;
        MoSi : out std_logic;
        SClk : out std_logic;
        CsNeg : out std_logic;
        Module_Adr : out std_logic_vector(23 downto 0);
        Module_Sel : out std_logic_vector(3 downto 0);
        Module_We : out std_logic;
        Module_Stb : out std_logic;
        Module_DatOut : out std_logic_vector(31 downto 0);
        Module_DatIn: in std_logic_vector(31 downto 0);
        Module_Ack : in std_logic;
        Module_Cyc : out std_logic_vector(0 downto 0)
    );
end;

architecture WasmFpgaFlashDefault of WasmFpgaFlash is

    signal Rst : std_logic;

    constant BootAddressPartitionSize : unsigned(23 downto 0) := x"001000"; -- 4kB
    constant BootAddressPartition0 : unsigned(23 downto 0) := x"200000";

    signal FlashControllerData : std_logic_vector(31 downto 0);
    signal FlashControllerBusy : std_logic;
    signal FlashControllerReadFromDeviceRun : std_logic;
    signal FlashControllerReadFromMemoryRun : std_logic;
    signal FlashControllerDeviceAddress : unsigned(23 downto 0);
    signal FlashControllerMemoryAddress : unsigned(10 downto 0);
    signal FlashControllerDeviceAddressEnd : unsigned(23 downto 0);
    signal FlashControllerMemoryAddressEnd : unsigned(10 downto 0);

    constant FlashControllerDataLength : unsigned(10 downto 0) := resize(x"400", 11); -- 1024 Bytes Page Size

    signal ModuleMemoryAddress : unsigned(23 downto 0);

    signal State : std_logic_vector(7 downto 0);
    signal ReturnState : std_logic_vector(7 downto 0);

    signal CounterEnClk25M : unsigned(1 downto 0);
    signal EnClk25M : std_logic;

begin

    Rst <= not nRst;

    FlashLoader : process(Clk, Rst) is
        constant Idle : std_logic_vector(7 downto 0) := x"00";
        constant CopyPartition0 : std_logic_vector(7 downto 0) := x"01";
        constant CopyPartition1 : std_logic_vector(7 downto 0) := x"02";
        constant CopyPartition2 : std_logic_vector(7 downto 0) := x"03";
        constant CopyPartition3 : std_logic_vector(7 downto 0) := x"04";
        constant Boot0 : std_logic_vector(7 downto 0) := x"05";
        constant ReadFromSpiFlashDevice0 : std_logic_vector(7 downto 0) := x"06";
        constant ReadFromSpiFlashDevice1 : std_logic_vector(7 downto 0) := x"07";
        constant ReadFromSpiFlashDevice2 : std_logic_vector(7 downto 0) := x"08";
        constant ReadFromSpiFlashMemory0 : std_logic_vector(7 downto 0) := x"09";
        constant ReadFromSpiFlashMemory1 : std_logic_vector(7 downto 0) := x"0A";
        constant ReadFromSpiFlashMemory2 : std_logic_vector(7 downto 0) := x"0B";
        constant WriteToModuleMemory0 : std_logic_vector(7 downto 0) := x"0C";
        constant WriteToModuleMemory1 : std_logic_vector(7 downto 0) := x"0D";
    begin
        if( Rst = '1' ) then
            Loaded <= '0';
            Module_Stb <= '0';
            Module_Cyc <= (others => '0');
            Module_Adr <= (others => '0');
            Module_Sel <= (others => '0');
            Module_We <= '0';
            Module_DatOut <= (others => '0');
            ModuleMemoryAddress <= (others => '0');
            FlashControllerDeviceAddress <= (others => '0');
            FlashControllerDeviceAddressEnd <= (others => '0');
            FlashControllerMemoryAddress <= (others => '0');
            FlashControllerMemoryAddressEnd <= (others => '0');
            FlashControllerReadFromDeviceRun <= '0';
            ReturnState <= (others => '0');
            State <= (others => '0');
        elsif rising_edge(Clk) then
            if( State = Idle ) then
                FlashControllerMemoryAddress <= to_unsigned(4, FlashControllerMemoryAddress'LENGTH);
                FlashControllerDeviceAddress <= BootAddressPartition0;
                FlashControllerDeviceAddressEnd <= BootAddressPartition0 + BootAddressPartitionSize;
                State <= CopyPartition0;
            elsif( State = CopyPartition0 ) then
                if( FlashControllerDeviceAddress = FlashControllerDeviceAddressEnd ) then
                    State <= Boot0;
                else
                    FlashControllerMemoryAddress <= to_unsigned(4, FlashControllerMemoryAddress'LENGTH);
                    State <= CopyPartition1;
                end if;
            elsif( State = CopyPartition1 ) then
                FlashControllerMemoryAddressEnd <= FlashControllerMemoryAddress + FlashControllerDataLength;
                ReturnState <= CopyPartition2;
                State <= ReadFromSpiFlashDevice0;
            elsif( State = CopyPartition2 ) then
                if( FlashControllerMemoryAddress /= FlashControllerMemoryAddressEnd) then
                    ReturnState <= CopyPartition3;
                    State <= ReadFromSpiFlashMemory0;
                else
                    FlashControllerDeviceAddress <= FlashControllerDeviceAddress + FlashControllerDataLength;
                    State <= CopyPartition0;
                end if;
            elsif( State = CopyPartition3 ) then
                ReturnState <= CopyPartition2;
                State <= WriteToModuleMemory0;
            elsif( State = Boot0 ) then
                Loaded <= '1';
            --
            -- Read from SPI Flash Device
            --
            elsif( State = ReadFromSpiFlashDevice0 ) then
                FlashControllerReadFromDeviceRun <= '1';
                State <= ReadFromSpiFlashDevice1;
            elsif( State = ReadFromSpiFlashDevice1 ) then
                FlashControllerReadFromDeviceRun <= '0';
                State <= ReadFromSpiFlashDevice2;
            elsif( State = ReadFromSpiFlashDevice2 ) then
                if( FlashControllerBusy = '0' ) then
                    State <= ReturnState;
                end if;
            --
            -- Read from SPI Flash Memory
            --
            elsif( State = ReadFromSpiFlashMemory0 ) then
                FlashControllerReadFromMemoryRun <= '1';
                State <= ReadFromSpiFlashMemory1;
            elsif( State = ReadFromSpiFlashMemory1 ) then
                FlashControllerReadFromMemoryRun <= '0';
                State <= ReadFromSpiFlashMemory2;
            elsif( State = ReadFromSpiFlashMemory2 ) then
                if( FlashControllerBusy = '0' ) then
                    FlashControllerMemoryAddress <= FlashControllerMemoryAddress + 4;
                    State <= ReturnState;
                end if;
            --
            -- Write to WASM Module Memory
            --
            elsif( State = WriteToModuleMemory0 ) then
                Module_Stb <= '1';
                Module_Cyc <= "1";
                Module_We <= '1';
                Module_Adr <= std_logic_vector(ModuleMemoryAddress);
                Module_DatOut <= FlashControllerData;
                Module_Sel <= (others => '1');
                State <= WriteToModuleMemory1;
            elsif( State = WriteToModuleMemory1 ) then
                if ( Module_Ack = '1' ) then
                    Module_Stb <= '0';
                    Module_Cyc <= "0";
                    Module_We <= '0';
                    Module_Adr <= (others => '0');
                    Module_DatOut <= (others => '0');
                    Module_Sel <= (others => '0');
                    ModuleMemoryAddress <= ModuleMemoryAddress + 1;
                    State <= ReturnState;
                end if;
            end if;
        end if;
    end process;

    EnClk25MGen : process (Clk, Rst) is
    begin
        if( Rst = '1' ) then
            EnClk25M <= '0';
            CounterEnClk25M <= (others => '0');
        elsif rising_edge(Clk) then
            EnClk25M <= '0';
            CounterEnClk25M <= CounterEnClk25M + 1;
            if( CounterEnClk25M = to_unsigned(2, CounterEnClk25M'LENGTH) ) then
                EnClk25M <= '1';
            end if;
        end if;
    end process;

    WasmFpgaFlashController_i : entity work.WasmFpgaFlashController
        port map (
            Clk => Clk,
            nRst => nRst,
            EnClk25M => EnClk25M,
            Busy => FlashControllerBusy,
            ReadFromDeviceRun => FlashControllerReadFromDeviceRun,
            DeviceAddress => std_logic_vector(FlashControllerDeviceAddress),
            ReadFromMemoryRun => FlashControllerReadFromMemoryRun,
            MemoryAddress => std_logic_vector(FlashControllerMemoryAddress),
            DataLength => std_logic_vector(FlashControllerDataLength),
            Data => FlashControllerData,
            SpiFlash_MiSo => MiSo,
            SpiFlash_MoSi => MoSi,
            SpiFlash_SClk => SClk,
            SpiFlash_CsNeg => CsNeg
        );

end architecture;
