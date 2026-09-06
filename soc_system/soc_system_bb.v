
module soc_system (
	clk_clk,
	reset_reset_n,
	memory_mem_a,
	memory_mem_ba,
	memory_mem_ck,
	memory_mem_ck_n,
	memory_mem_cke,
	memory_mem_cs_n,
	memory_mem_ras_n,
	memory_mem_cas_n,
	memory_mem_we_n,
	memory_mem_reset_n,
	memory_mem_dq,
	memory_mem_dqs,
	memory_mem_dqs_n,
	memory_mem_odt,
	memory_mem_dm,
	memory_oct_rzqin,
	hps_io_hps_io_gpio_inst_GPIO09,
	hps_io_hps_io_gpio_inst_LOANIO49,
	hps_io_hps_io_gpio_inst_LOANIO50,
	loan_io_in,
	loan_io_out,
	loan_io_oe,
	mpu_events_eventi,
	mpu_events_evento,
	mpu_events_standbywfe,
	mpu_events_standbywfi);	

	input		clk_clk;
	input		reset_reset_n;
	output	[12:0]	memory_mem_a;
	output	[2:0]	memory_mem_ba;
	output		memory_mem_ck;
	output		memory_mem_ck_n;
	output		memory_mem_cke;
	output		memory_mem_cs_n;
	output		memory_mem_ras_n;
	output		memory_mem_cas_n;
	output		memory_mem_we_n;
	output		memory_mem_reset_n;
	inout	[7:0]	memory_mem_dq;
	inout		memory_mem_dqs;
	inout		memory_mem_dqs_n;
	output		memory_mem_odt;
	output		memory_mem_dm;
	input		memory_oct_rzqin;
	inout		hps_io_hps_io_gpio_inst_GPIO09;
	inout		hps_io_hps_io_gpio_inst_LOANIO49;
	inout		hps_io_hps_io_gpio_inst_LOANIO50;
	output	[66:0]	loan_io_in;
	input	[66:0]	loan_io_out;
	input	[66:0]	loan_io_oe;
	input		mpu_events_eventi;
	output		mpu_events_evento;
	output	[1:0]	mpu_events_standbywfe;
	output	[1:0]	mpu_events_standbywfi;
endmodule
