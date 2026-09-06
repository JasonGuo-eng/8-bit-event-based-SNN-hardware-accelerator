	soc_system u0 (
		.clk_clk                          (<connected-to-clk_clk>),                          //        clk.clk
		.reset_reset_n                    (<connected-to-reset_reset_n>),                    //      reset.reset_n
		.memory_mem_a                     (<connected-to-memory_mem_a>),                     //     memory.mem_a
		.memory_mem_ba                    (<connected-to-memory_mem_ba>),                    //           .mem_ba
		.memory_mem_ck                    (<connected-to-memory_mem_ck>),                    //           .mem_ck
		.memory_mem_ck_n                  (<connected-to-memory_mem_ck_n>),                  //           .mem_ck_n
		.memory_mem_cke                   (<connected-to-memory_mem_cke>),                   //           .mem_cke
		.memory_mem_cs_n                  (<connected-to-memory_mem_cs_n>),                  //           .mem_cs_n
		.memory_mem_ras_n                 (<connected-to-memory_mem_ras_n>),                 //           .mem_ras_n
		.memory_mem_cas_n                 (<connected-to-memory_mem_cas_n>),                 //           .mem_cas_n
		.memory_mem_we_n                  (<connected-to-memory_mem_we_n>),                  //           .mem_we_n
		.memory_mem_reset_n               (<connected-to-memory_mem_reset_n>),               //           .mem_reset_n
		.memory_mem_dq                    (<connected-to-memory_mem_dq>),                    //           .mem_dq
		.memory_mem_dqs                   (<connected-to-memory_mem_dqs>),                   //           .mem_dqs
		.memory_mem_dqs_n                 (<connected-to-memory_mem_dqs_n>),                 //           .mem_dqs_n
		.memory_mem_odt                   (<connected-to-memory_mem_odt>),                   //           .mem_odt
		.memory_mem_dm                    (<connected-to-memory_mem_dm>),                    //           .mem_dm
		.memory_oct_rzqin                 (<connected-to-memory_oct_rzqin>),                 //           .oct_rzqin
		.hps_io_hps_io_gpio_inst_GPIO09   (<connected-to-hps_io_hps_io_gpio_inst_GPIO09>),   //     hps_io.hps_io_gpio_inst_GPIO09
		.hps_io_hps_io_gpio_inst_LOANIO49 (<connected-to-hps_io_hps_io_gpio_inst_LOANIO49>), //           .hps_io_gpio_inst_LOANIO49
		.hps_io_hps_io_gpio_inst_LOANIO50 (<connected-to-hps_io_hps_io_gpio_inst_LOANIO50>), //           .hps_io_gpio_inst_LOANIO50
		.loan_io_in                       (<connected-to-loan_io_in>),                       //    loan_io.in
		.loan_io_out                      (<connected-to-loan_io_out>),                      //           .out
		.loan_io_oe                       (<connected-to-loan_io_oe>),                       //           .oe
		.mpu_events_eventi                (<connected-to-mpu_events_eventi>),                // mpu_events.eventi
		.mpu_events_evento                (<connected-to-mpu_events_evento>),                //           .evento
		.mpu_events_standbywfe            (<connected-to-mpu_events_standbywfe>),            //           .standbywfe
		.mpu_events_standbywfi            (<connected-to-mpu_events_standbywfi>)             //           .standbywfi
	);

