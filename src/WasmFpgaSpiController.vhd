library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;

entity SpiController is
    generic (
        ChipSelectHoldTimeMultiplier : unsigned(2 downto 0)
    );
    port (
        Clk : in std_logic;
        nRst : in std_logic;
        EnSpiClk : in std_logic;
        Busy : out std_logic;
        Run : in std_logic;
        SequenceLength : in std_logic_vector(10 downto 0);
        Web : in std_logic_vector(0 to 0);
        AddrB : in std_logic_vector(10 downto 0);
        DinB : in std_logic_vector(8 downto 0);
        Doutb : out std_logic_vector(8 downto 0);
        So : out std_logic;
        Si: in std_logic;
        SClk : out std_logic;
        CsNeg : out std_logic
    );
end;

architecture SpiControllerDefault of SpiController is

    signal SpiControllerNextByte : std_logic_vector(8 downto 0);
    signal SpiControllerByteIndex : unsigned(2 downto 0);

    signal SpiControllerSiByte : std_logic_vector(7 downto 0);
    signal SpiControllerSoByte : std_logic_vector(7 downto 0);

    signal SpiControllerState : std_logic_vector(7 downto 0);
    signal SpiControllerReturnState : std_logic_vector(7 downto 0);

    signal SpiSclkGenState : std_logic_vector(7 downto 0);

    signal SClkCounter : unsigned(2 downto 0);
    signal SClkHalfPeriod : unsigned(3 downto 0);
    signal SpiClkGenReady : std_logic;

    signal SpiControllerSi : std_logic;
    signal SpiControllerSo : std_logic;
    signal SpiControllerCsNeg : std_logic;

    signal SpiControllerAddress : unsigned(10 downto 0);
    signal SpiControllerEofAddress : std_logic_vector(10 downto 0);

    signal SpiControllerTempByte : std_logic_vector(7 downto 0);
    signal SpiControllerBusy : std_logic;
    signal SpiControllerSclkRun : std_logic;

    signal ChipSelectHoldTimeMultiplierCount : unsigned(2 downto 0);

    signal WeA : std_logic_vector(0 to 0);
    signal WeAIndirection : std_logic_vector(0 to 0);
    signal WeBIndirection : std_logic_vector(0 to 0);
    signal AddrA : std_logic_vector(10 downto 0);
    signal DinA : std_logic_vector(8 downto 0);
    signal DoutA : std_logic_vector(8 downto 0);

    signal SpiControllerSclk : std_logic;

    signal Rst : std_logic;

begin

    Rst <= not nRst;

    SpiControllerEofAddress <= SequenceLength;

    Busy <= SpiControllerBusy;

    SpiControllerSi <= Si;

    SClk <= '1' when SpiControllerSclk = '1' else '0';

    So <= '1' when SpiControllerSo = '1' else '0';
    CsNeg <= '1' when SpiControllerCsNeg = '1' else '0';

    SpiSclkGen : process (Clk, Rst) is
      constant SpiSclkGenInit0 : std_logic_vector(7 downto 0) := x"00";
      constant SpiSclkGenInit1 : std_logic_vector(7 downto 0) := x"01";
      constant SpiSclkGenRun0 : std_logic_vector(7 downto 0) := x"02";
      constant SpiSclkGenError0 : std_logic_vector(7 downto 0) := x"03";
    begin
        if( Rst = '1' ) then
            SClkCounter <= (others => '0');
            SClkHalfPeriod <= (others => '0');
            SpiControllerSclk <= '0';
            SpiClkGenReady <= '0';
            SpiSclkGenState <= (others => '0');
        elsif rising_edge(Clk) then
            if( SpiSclkGenState = SpiSclkGenInit0 ) then
                SpiClkGenReady <= '0';
                if( EnSpiClk = '1' ) then
                    SClkHalfPeriod <= to_unsigned(1, SClkHalfPeriod'LENGTH);
                    SpiSclkGenState <= SpiSclkGenInit1;
                end if;
            elsif( SpiSclkGenState = SpiSclkGenInit1 ) then
                SClkHalfPeriod <= SClkHalfPeriod + 1;
                if( EnSpiClk = '1' ) then
                    SpiClkGenReady <= '1';
                    SClkHalfPeriod <= "0" & SClkHalfPeriod(3 downto 1);
                    SpiSclkGenState <= SpiSclkGenRun0;
                end if;
            elsif( SpiSclkGenState = SpiSclkGenRun0 ) then
                if( EnSpiClk = '1' ) then
                    SpiControllerSclk <= '0';
                    SClkCounter <= to_unsigned(1, SClkCounter'LENGTH);
                end if;
                if( SClkCounter = SClkHalfPeriod ) then
                    if( SpiControllerSclkRun = '0' ) then
                        SpiControllerSclk <= '1';
                    end if;
                    SClkCounter <= to_unsigned(0, SClkCounter'LENGTH);
                elsif( SClkCounter /= to_unsigned(0, SClkCounter'LENGTH) ) then
                    SClkCounter <= SClkCounter + 1;
                end if;
                SpiSclkGenState <= SpiSclkGenRun0;
            elsif( SpiSclkGenState = SpiSclkGenError0 ) then
                SpiSclkGenState <= SpiSclkGenError0;
            else
                SpiSclkGenState <= SpiSclkGenError0;
            end if;
        end if;
    end process;

    SpiController : process (Clk, Rst) is
      constant SpiControllerWaitForRun0 : std_logic_vector(7 downto 0) := x"00";
      constant SpiControllerWaitForRun1 : std_logic_vector(7 downto 0) := x"01";
      constant SpiControllerReadByte0 : std_logic_vector(7 downto 0) := x"02";
      constant SpiControllerReadByte1 : std_logic_vector(7 downto 0) := x"03";
      constant SpiControllerReadByte2 : std_logic_vector(7 downto 0) := x"04";
      constant SpiControllerReadByte3 : std_logic_vector(7 downto 0) := x"05";
      constant SpiControllerWriteByte0 : std_logic_vector(7 downto 0) := x"06";
      constant SpiControllerWriteByte1 : std_logic_vector(7 downto 0) := x"07";
      constant SpiControllerDispatch0 : std_logic_vector(7 downto 0) := x"08";
      constant SpiControllerDispatch1 : std_logic_vector(7 downto 0) := x"09";
      constant SpiControllerDispatch2 : std_logic_vector(7 downto 0) := x"0A";
      constant SpiControllerError0 : std_logic_vector(7 downto 0) := x"0B";
    begin
        if rising_edge(Clk) then
            if( Rst = '1' ) then
                WeA <= (others => '0');
                AddrA <= (others => '0');
                DinA <= (others => '0');
                ChipSelectHoldTimeMultiplierCount <= (others => '0');
                SpiControllerSo <= '0';
                SpiControllerCsNeg <= '1';
                SpiControllerBusy <= '1';
                SpiControllerNextByte <= (others => '0');
                SpiControllerByteIndex <= (others => '0');
                SpiControllerTempByte <= (others => '0');
                SpiControllerSiByte <= (others => '0');
                SpiControllerSoByte <= (others => '0');
                SpiControllerAddress <= (others => '0');
                SpiControllerSclkRun <= '1';
                SpiControllerReturnState <= (others => '0');
                SpiControllerState <= SpiControllerWaitForRun0;
            else
                if( EnSpiClk = '1' ) then
                    if ( SpiControllerState = SpiControllerWaitForRun0 ) then
                        SpiControllerBusy <= '1';
                        if( SpiClkGenReady = '1' ) then
                            SpiControllerState <= SpiControllerWaitForRun1;
                        end if;
                    elsif ( SpiControllerState = SpiControllerWaitForRun1 ) then
                        SpiControllerBusy <= '0';
                        SpiControllerSo <= '0';
                        SpiControllerCsNeg <= '1';
                        SpiControllerSclkRun <= '1';
                        SpiControllerAddress <= (others => '0');
                        AddrA <= (others => '0');
                        if ( Run = '1' ) then
                            SpiControllerBusy <= '1';
                            if( SpiControllerAddress = unsigned(SpiControllerEofAddress) ) then
                                SpiControllerState <= SpiControllerWaitForRun1;
                            else
                                SpiControllerState <= SpiControllerDispatch0;
                            end if;
                        end if;
                    --
                    -- Dispatch
                    --
                    elsif ( SpiControllerState = SpiControllerDispatch0 ) then
                        SpiControllerState <= SpiControllerDispatch1;
                    elsif ( SpiControllerState = SpiControllerDispatch1 ) then
                        SpiControllerNextByte <= DoutA;
                        SpiControllerState <= SpiControllerDispatch2;
                    elsif ( SpiControllerState = SpiControllerDispatch2 ) then
                        SpiControllerCsNeg <= '0';
                        SpiControllerAddress <= SpiControllerAddress + 1;
                        AddrA <= std_logic_vector(SpiControllerAddress + 1);
                        if( SpiControllerNextByte(8) = '1' ) then
                            SpiControllerSoByte <= DoutA(7 downto 0);
                            SpiControllerState <= SpiControllerWriteByte0;
                        else
                            SpiControllerState <= SpiControllerReadByte0;
                        end if;
                    --
                    -- Write Byte to Slave and Dispatch
                    --
                    elsif ( SpiControllerState = SpiControllerWriteByte0 ) then
                        WeA <= "0";
                        SpiControllerSclkRun <= '0';
                        SpiControllerSoByte <= SpiControllerSoByte(6 downto 0) & "0";
                        SpiControllerSo <= SpiControllerSoByte(7);
                        SpiControllerByteIndex <= SpiControllerByteIndex + 1;
                        SpiControllerNextByte <= DoutA;
                        if( SpiControllerByteIndex = 7 ) then
                            SpiControllerByteIndex <= (others => '0');
                            SpiControllerAddress <= SpiControllerAddress + 1;
                            AddrA <= std_logic_vector(SpiControllerAddress + 1);
                            if( SpiControllerAddress = unsigned(SpiControllerEofAddress) ) then
                                ChipSelectHoldTimeMultiplierCount <= (others => '0');
                                SpiControllerState <= SpiControllerReadByte1;
                            elsif( SpiControllerNextByte(8) = '1' ) then
                                SpiControllerSoByte <= SpiControllerNextByte(7 downto 0);
                                SpiControllerState <= SpiControllerWriteByte0;
                            else
                                SpiControllerSiByte <= (others => '0');
                                SpiControllerState <= SpiControllerWriteByte1;
                            end if;
                        else
                            SpiControllerState <= SpiControllerWriteByte0;
                        end if;
                    elsif ( SpiControllerState = SpiControllerWriteByte1 ) then
                        SpiControllerSo <= '0';
                        SpiControllerState <= SpiControllerReadByte0;
                    --
                    -- Read Byte to Slave and Dispatch
                    --
                    elsif ( SpiControllerState = SpiControllerReadByte0 ) then
                        WeA <= "0";
                        SpiControllerSiByte <= SpiControllerSiByte(6 downto 0) & SpiControllerSi;
                        SpiControllerByteIndex <= SpiControllerByteIndex + 1;
                        SpiControllerNextByte <= DoutA;
                        if( SpiControllerByteIndex = 7 ) then
                            SpiControllerByteIndex <= (others => '0');
                            SpiControllerAddress <= SpiControllerAddress + 1;
                            WeA <= "1";
                            AddrA <= std_logic_vector(SpiControllerAddress - 1);
                            DinA <= "0" & SpiControllerSiByte(6 downto 0) & SpiControllerSi;
                            if( SpiControllerAddress = unsigned(SpiControllerEofAddress) ) then
                                ChipSelectHoldTimeMultiplierCount <= (others => '0');
                                SpiControllerState <= SpiControllerReadByte1;
                            elsif( SpiControllerNextByte(8) = '1' ) then
                                SpiControllerSoByte <= SpiControllerNextByte(7 downto 0);
                                SpiControllerState <= SpiControllerWriteByte0;
                            else
                                SpiControllerSiByte <= (others => '0');
                                SpiControllerState <= SpiControllerReadByte0;
                            end if;
                        else
                            SpiControllerState <= SpiControllerReadByte0;
                        end if;
                    elsif ( SpiControllerState = SpiControllerReadByte1 ) then
                        WeA <= "0";
                        ChipSelectHoldTimeMultiplierCount <= ChipSelectHoldTimeMultiplierCount + 1;
                        if( ChipSelectHoldTimeMultiplierCount = unsigned(ChipSelectHoldTimeMultiplier) ) then
                            SpiControllerSclkRun <= '1';
                            SpiControllerState <= SpiControllerWaitForRun1;
                        else
                            SpiControllerState <= SpiControllerReadByte1;
                        end if;
                    --
                    -- Error State
                    --
                    elsif ( SpiControllerState = SpiControllerError0 ) then
                        SpiControllerState <= SpiControllerError0;
                    else
                        SpiControllerState <= SpiControllerError0;
                    end if;
                end if;
            end if;
        end if;
    end process;

    WeAIndirection <= "1" when WeA = "1" else "0";
    WeBIndirection <= "1" when WeB = "1" else "0";

    SpiRam_i : entity work.WasmFpgaSpiRam
      port map (
        clka => Clk,
        wea => WeAIndirection,
        addra => AddrA,
        dina => DinA,
        douta => DoutA,
        clkb => Clk,
        web => WeBIndirection,
        addrb => AddrB,
        dinb => DinB,
        doutb => DoutB
      );

end architecture;
