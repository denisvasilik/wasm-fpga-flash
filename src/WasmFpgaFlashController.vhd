library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity WasmFpgaFlashController is
    port (
        Clk : in std_logic;
        nRst : in std_logic;
        EnClk25M : in std_logic;
        Busy : out std_logic;
        ReadFromDeviceRun : in std_logic;
        DeviceAddress : in std_logic_vector(23 downto 0);
        ReadFromMemoryRun : in std_logic;
        MemoryAddress : in std_logic_vector(10 downto 0);
        DataLength : in std_logic_vector(10 downto 0);
        Data : out std_logic_vector(31 downto 0);
        SpiFlash_MiSo : in std_logic;
        SpiFlash_MoSi : out std_logic;
        SpiFlash_SClk : out std_logic;
        SpiFlash_CsNeg : out std_logic
    );
end;

architecture WasmFpgaFlashControllerDefault of WasmFpgaFlashController is

    -- SPI Flash Instructions
    constant FlashSpiCmdPageProgram : std_logic_vector(7 downto 0) := x"02";
    constant FlashSpiCmdSubSectorErase : std_logic_vector(7 downto 0) := x"20";
    constant FlashSpiCmdSectorErase : std_logic_vector(7 downto 0) := x"D8";
    constant FlashSpiCmdBulkErase : std_logic_vector(7 downto 0) := x"C7";
    constant FlashSpiCmdWriteEnable : std_logic_vector(7 downto 0) := x"06";
    constant FlashSpiCmdWriteDisable : std_logic_vector(7 downto 0) := x"04";
    constant FlashSpiCmdReadStatusReg : std_logic_vector(7 downto 0) := x"05";
    constant FlashSpiCmdReadId : std_logic_vector(7 downto 0) := x"9E";
    constant FlashSpiCmdRead : std_logic_vector(7 downto 0) := x"03";

    constant FlashSpiPageSize : unsigned(7 downto 0) := to_unsigned(255, 8);
    constant FlashSpiProgramCommandSize : unsigned(7 downto 0) := to_unsigned(4, 8);

    signal SpiControllerRun : std_logic;
    signal SpiControllerBusy : std_logic;
    signal SpiControllerSequenceLength : std_logic_vector(10 downto 0);

    signal FlashSpiControllerMemoryAddress : unsigned(10 downto 0);
    signal FlashSpiControllerMemoryAddressEnd : unsigned(10 downto 0);

    signal FlashSpiControllerSequenceLength : std_logic_vector(10 downto 0);

    signal FlashSpiControllerReadFromDeviceRun : std_logic;
    signal FlashSpiControllerReadFromMemoryRun : std_logic;

    signal FlashSpiControllerState : std_logic_vector(7 downto 0);
    signal FlashSpiControllerReturnState : std_logic_vector(7 downto 0);
    signal FlashSpiControllerReturnReturnState : std_logic_vector(7 downto 0);

    signal WeB : std_logic_vector(0 downto 0);
    signal AddrB : std_logic_vector(10 downto 0);
    signal DinB : std_logic_vector(8 downto 0);
    signal DoutB : std_logic_vector(8 downto 0);

    signal FlashSpiCommand : std_logic_vector(7 downto 0);
    signal FlashSpiAddress : std_logic_vector(23 downto 0);

    signal FlashSpiControllerRawCommand : std_logic_vector(8 downto 0);

    signal FlashSpiControllerReadByteRun : std_logic;
    signal FlashSpiControllerReadByteAddress : std_logic_vector(23 downto 0);

    signal Rst : std_logic;

begin

    Rst <= not nRst;

    FlashSpiController : process (Clk, Rst) is
        constant FlashSpiControllerWaitForRun0 : std_logic_vector(7 downto 0) := x"00";
        constant FlashSpiControllerWrite0 : std_logic_vector(7 downto 0) := x"01";
        constant FlashSpiControllerWrite1 : std_logic_vector(7 downto 0) := x"02";
        constant FlashSpiControllerWrite2 : std_logic_vector(7 downto 0) := x"03";
        constant FlashSpiControllerControl0 : std_logic_vector(7 downto 0) := x"04";
        constant FlashSpiControllerRun0 : std_logic_vector(7 downto 0) := x"05";
        constant FlashSpiControllerRun1 : std_logic_vector(7 downto 0) := x"06";
        constant FlashSpiControllerRun2 : std_logic_vector(7 downto 0) := x"07";
        constant FlashSpiControllerRead0 : std_logic_vector(7 downto 0) := x"08";
        constant FlashSpiControllerRead1 : std_logic_vector(7 downto 0) := x"09";
        constant FlashSpiControllerWriteSpiRam0 : std_logic_vector(7 downto 0) := x"0A";
        constant FlashSpiControllerWriteSpiRam1 : std_logic_vector(7 downto 0) := x"0B";
        constant FlashSpiControllerWriteSpiRam2 : std_logic_vector(7 downto 0) := x"0C";
        constant FlashSpiControllerReadFromMemory0 : std_logic_vector(7 downto 0) := x"0D";
        constant FlashSpiControllerReadFromMemory1 : std_logic_vector(7 downto 0) := x"0E";
        constant FlashSpiControllerReadFromMemory2 : std_logic_vector(7 downto 0) := x"0F";
        constant FlashSpiControllerReadFromMemory3 : std_logic_vector(7 downto 0) := x"10";
        constant FlashSpiControllerCommandAndAddress0 : std_logic_vector(7 downto 0) := x"11";
        constant FlashSpiControllerCommandAndAddress1 : std_logic_vector(7 downto 0) := x"12";
        constant FlashSpiControllerCommandAndAddress2 : std_logic_vector(7 downto 0) := x"13";
        constant FlashSpiControllerCommandAndAddress3 : std_logic_vector(7 downto 0) := x"14";
        constant FlashSpiControllerCommandAndAddress4 : std_logic_vector(7 downto 0) := x"15";
        constant FlashSpiControllerWriteToMemory0 : std_logic_vector(7 downto 0) := x"16";
        constant FlashSpiControllerWriteToMemory1 : std_logic_vector(7 downto 0) := x"17";
        constant FlashSpiControllerExecuteCommandMemory0 : std_logic_vector(7 downto 0) := x"18";
        constant FlashSpiControllerError0 : std_logic_vector(7 downto 0) := x"FF";
    begin
        if rising_edge(Clk) then
            if( Rst = '1' ) then
                FlashSpiCommand <= (others => '0');
                FlashSpiAddress <= (others => '0');
                Data <= (others => '0');
                WeB <= (others => '0');
                AddrB <= (others => '0');
                DinB <= (others => '0');
                SpiControllerSequenceLength <= (others => '0');
                SpiControllerRun <= '0';
                Busy <= '1';
                FlashSpiControllerReturnState <= (others => '0');
                FlashSpiControllerReturnReturnState <= (others => '0');
                FlashSpiControllerState <= FlashSpiControllerWaitForRun0;
            elsif( FlashSpiControllerState = FlashSpiControllerWaitForRun0 ) then
                Busy <= '0';
                if( ReadFromDeviceRun = '1' ) then
                    Busy <= '1';
                    FlashSpiControllerState <= FlashSpiControllerRead0;
                elsif( ReadFromMemoryRun = '1' ) then
                    Busy <= '1';
                    FlashSpiControllerMemoryAddress <= unsigned(MemoryAddress);
                    FlashSpiControllerMemoryAddressEnd <= unsigned(MemoryAddress) +
                                                          to_unsigned(4, FlashSpiControllerMemoryAddressEnd'LENGTH);
                    FlashSpiControllerState <= FlashSpiControllerReadFromMemory0;
                end if;
            --
            -- Low-Level Access: Read from SPI Command Memory
            --
            elsif( FlashSpiControllerState = FlashSpiControllerReadFromMemory0 ) then
                if (FlashSpiControllerMemoryAddress /= FlashSpiControllerMemoryAddressEnd) then
                    AddrB <= std_logic_vector(FlashSpiControllerMemoryAddress);
                    FlashSpiControllerState <= FlashSpiControllerReadFromMemory1;
                else
                    FlashSpiControllerState <= FlashSpiControllerWaitForRun0;
                end if;
            elsif( FlashSpiControllerState = FlashSpiControllerReadFromMemory1 ) then
                FlashSpiControllerState <= FlashSpiControllerReadFromMemory2;
            elsif( FlashSpiControllerState = FlashSpiControllerReadFromMemory2 ) then
                FlashSpiControllerState <= FlashSpiControllerReadFromMemory3;
            elsif( FlashSpiControllerState = FlashSpiControllerReadFromMemory3 ) then
                FlashSpiControllerState <= FlashSpiControllerReadFromMemory0;
                FlashSpiControllerMemoryAddress <= FlashSpiControllerMemoryAddress + 1;
                if (FlashSpiControllerMemoryAddress(1 downto 0) = "00") then
                    Data(7 downto 0) <= DoutB(7 downto 0);
                elsif(FlashSpiControllerMemoryAddress(1 downto 0) = "01") then
                    Data(15 downto 8) <= DoutB(7 downto 0);
                elsif(FlashSpiControllerMemoryAddress(1 downto 0) = "10") then
                    Data(23 downto 16) <= DoutB(7 downto 0);
                elsif(FlashSpiControllerMemoryAddress(1 downto 0) = "11") then
                    Data(31 downto 24) <= DoutB(7 downto 0);
                end if;
            --
            -- Low-Level Access: Write to SPI Command Memory (not used)
            --
            elsif( FlashSpiControllerState = FlashSpiControllerWriteToMemory0 ) then
                AddrB <= MemoryAddress;
                FlashSpiControllerState <= FlashSpiControllerWriteToMemory1;
            elsif( FlashSpiControllerState = FlashSpiControllerWriteToMemory1 ) then
                DinB <= FlashSpiControllerRawCommand;
                AddrB <= MemoryAddress;
                FlashSpiControllerReturnState <= FlashSpiControllerWaitForRun0;
                FlashSpiControllerState <= FlashSpiControllerWriteSpiRam0;
            --
            -- Low-Level Access: Execute SPI Command Memory (not used)
            --
            elsif( FlashSpiControllerState = FlashSpiControllerExecuteCommandMemory0 ) then
                SpiControllerSequenceLength <= FlashSpiControllerSequenceLength;
                FlashSpiControllerReturnState <= FlashSpiControllerWaitForRun0;
                FlashSpiControllerState <= FlashSpiControllerRun0;
            --
            -- Read from SPI Flash Device
            --
            elsif( FlashSpiControllerState = FlashSpiControllerRead0 ) then
                FlashSpiCommand <= FlashSpiCmdRead;
                FlashSpiAddress <= DeviceAddress;
                FlashSpiControllerReturnReturnState <= FlashSpiControllerRead1;
                FlashSpiControllerState <= FlashSpiControllerCommandAndAddress0;
            elsif( FlashSpiControllerState = FlashSpiControllerRead1 ) then
                SpiControllerSequenceLength <= std_logic_vector(to_unsigned(4, SpiControllerSequenceLength'LENGTH) + unsigned(DataLength));
                FlashSpiControllerReturnState <= FlashSpiControllerWaitForRun0;
                FlashSpiControllerState <= FlashSpiControllerRun0;
            --
            -- SPI Controller
            --
            elsif( FlashSpiControllerState = FlashSpiControllerRun0 ) then
                if( EnClk25M = '1' and SpiControllerBusy = '0' ) then
                    SpiControllerRun <= '1';
                    FlashSpiControllerState <= FlashSpiControllerRun1;
                end if;
            elsif( FlashSpiControllerState = FlashSpiControllerRun1 ) then
                if( EnClk25M = '1' ) then
                    SpiControllerRun <= '0';
                    FlashSpiControllerState <= FlashSpiControllerRun2;
                end if;
            elsif( FlashSpiControllerState = FlashSpiControllerRun2 ) then
                if( SpiControllerBusy = '0' ) then
                    FlashSpiControllerState <= FlashSpiControllerReturnState;
                end if;
            --
            -- Write to SpiRam
            --
            elsif( FlashSpiControllerState = FlashSpiControllerWriteSpiRam0 ) then
                WeB <= "1";
                FlashSpiControllerState <= FlashSpiControllerWriteSpiRam1;
            elsif( FlashSpiControllerState = FlashSpiControllerWriteSpiRam1 ) then
                WeB <= "0";
                FlashSpiControllerState <= FlashSpiControllerWriteSpiRam2;
            elsif( FlashSpiControllerState = FlashSpiControllerWriteSpiRam2 ) then
                FlashSpiControllerState <= FlashSpiControllerReturnState;
            --
            -- Write Command and Address to SPI Command Memory
            --
            elsif( FlashSpiControllerState = FlashSpiControllerCommandAndAddress0 ) then
                DinB <= "1" & FlashSpiCommand;
                AddrB <= (10 downto 4 => '0') & x"0";
                FlashSpiControllerReturnState <= FlashSpiControllerCommandAndAddress1;
                FlashSpiControllerState <= FlashSpiControllerWriteSpiRam0;
            elsif( FlashSpiControllerState = FlashSpiControllerCommandAndAddress1 ) then
                DinB <= "1" & FlashSpiAddress(23 downto 16); -- Address Byte 3
                AddrB <= (10 downto 4 => '0') & x"1";
                FlashSpiControllerReturnState <= FlashSpiControllerCommandAndAddress2;
                FlashSpiControllerState <= FlashSpiControllerWriteSpiRam0;
            elsif( FlashSpiControllerState = FlashSpiControllerCommandAndAddress2 ) then
                DinB <= "1" & FlashSpiAddress(15 downto 8); -- Address Byte 2
                AddrB <= (10 downto 4 => '0') & x"2";
                FlashSpiControllerReturnState <= FlashSpiControllerCommandAndAddress3;
                FlashSpiControllerState <= FlashSpiControllerWriteSpiRam0;
            elsif( FlashSpiControllerState = FlashSpiControllerCommandAndAddress3 ) then
                DinB <= "1" & FlashSpiAddress(7 downto 0); -- Address Byte 1
                AddrB <= (10 downto 4 => '0') & x"3";
                FlashSpiControllerReturnState <= FlashSpiControllerReturnReturnState;
                FlashSpiControllerState <= FlashSpiControllerWriteSpiRam0;
            --
            -- Error State
            --
            elsif( FlashSpiControllerState = FlashSpiControllerError0 ) then
                FlashSpiControllerState <= FlashSpiControllerError0;
            else
                FlashSpiControllerState <= FlashSpiControllerError0;
            end if;
        end if;
    end process;

    SpiController_i : entity work.SpiController
        generic map (
            ChipSelectHoldTimeMultiplier => "000"
        )
        port map (
            Clk => Clk,
            nRst => nRst,
            EnSpiClk => EnClk25M,
            Busy => SpiControllerBusy,
            Run => SpiControllerRun,
            SequenceLength => SpiControllerSequenceLength,
            WeB => WeB,
            AddrB => AddrB,
            DinB => DinB,
            DoutB => DoutB,
            So => SpiFlash_MoSi,
            Si => SpiFlash_MiSo,
            SClk => SpiFlash_SClk,
            CsNeg => SpiFlash_CsNeg
        );

end;