#!/usr/bin/env python3
# -*- coding: utf-8 -*-

#
# SPDX-License-Identifier: GPL-3.0
#
# GNU Radio Python Flow Graph
# Title: FMtran
# GNU Radio version: 3.10.9.2

from PyQt5 import Qt
from gnuradio import qtgui
from PyQt5 import QtCore
from gnuradio import analog
from gnuradio import blocks
from gnuradio import filter
from gnuradio.filter import firdes
from gnuradio import gr
from gnuradio.fft import window
import sys
import signal
from PyQt5 import Qt
from argparse import ArgumentParser
from gnuradio.eng_arg import eng_float, intx
from gnuradio import eng_notation
import osmosdr
import time



class FMtran(gr.top_block, Qt.QWidget):

    def __init__(self):
        gr.top_block.__init__(self, "FMtran", catch_exceptions=True)
        Qt.QWidget.__init__(self)
        self.setWindowTitle("FMtran")
        qtgui.util.check_set_qss()
        try:
            self.setWindowIcon(Qt.QIcon.fromTheme('gnuradio-grc'))
        except BaseException as exc:
            print(f"Qt GUI: Could not set Icon: {str(exc)}", file=sys.stderr)
        self.top_scroll_layout = Qt.QVBoxLayout()
        self.setLayout(self.top_scroll_layout)
        self.top_scroll = Qt.QScrollArea()
        self.top_scroll.setFrameStyle(Qt.QFrame.NoFrame)
        self.top_scroll_layout.addWidget(self.top_scroll)
        self.top_scroll.setWidgetResizable(True)
        self.top_widget = Qt.QWidget()
        self.top_scroll.setWidget(self.top_widget)
        self.top_layout = Qt.QVBoxLayout(self.top_widget)
        self.top_grid_layout = Qt.QGridLayout()
        self.top_layout.addLayout(self.top_grid_layout)

        self.settings = Qt.QSettings("GNU Radio", "FMtran")

        try:
            geometry = self.settings.value("geometry")
            if geometry:
                self.restoreGeometry(geometry)
        except BaseException as exc:
            print(f"Qt GUI: Could not restore geometry: {str(exc)}", file=sys.stderr)

        ##################################################
        # Variables
        ##################################################
        self.samp_rate = samp_rate = 2000000
        self.center_fr = center_fr = 80e6
        self.audioRate = audioRate = 44100
        self.amplitude = amplitude = 0.2

        ##################################################
        # Blocks
        ##################################################

        self._center_fr_range = qtgui.Range(50e6, 200e6, 1, 80e6, 200)
        self._center_fr_win = qtgui.RangeWidget(self._center_fr_range, self.set_center_fr, "'center_fr'", "counter_slider", float, QtCore.Qt.Horizontal)
        self.top_layout.addWidget(self._center_fr_win)
        self.rational_resampler_xxx_0 = filter.rational_resampler_ccc(
                interpolation=samp_rate,
                decimation=176400,
                taps=[],
                fractional_bw=0)
        self.osmosdr_sink_0 = osmosdr.sink(
            args="numchan=" + str(1) + " " + ""
        )
        self.osmosdr_sink_0.set_clock_source('internal', 0)
        self.osmosdr_sink_0.set_time_source('external', 0)
        self.osmosdr_sink_0.set_time_now(osmosdr.time_spec_t(time.time()), osmosdr.ALL_MBOARDS)
        self.osmosdr_sink_0.set_sample_rate(samp_rate)
        self.osmosdr_sink_0.set_center_freq(center_fr, 0)
        self.osmosdr_sink_0.set_freq_corr(0, 0)
        self.osmosdr_sink_0.set_gain(20, 0)
        self.osmosdr_sink_0.set_if_gain(40, 0)
        self.osmosdr_sink_0.set_bb_gain(20, 0)
        self.osmosdr_sink_0.set_antenna('', 0)
        self.osmosdr_sink_0.set_bandwidth(0, 0)
        self.blocks_wavfile_source_0 = blocks.wavfile_source('C:\\Windows\\Media\\Alarm01.wav', True)
        self.blocks_multiply_const_vxx_0 = blocks.multiply_const_ff(0.2)
        self.analog_wfm_tx_0 = analog.wfm_tx(
        	audio_rate=audioRate,
        	quad_rate=(audioRate*4),
        	tau=(75e-6),
        	max_dev=75e3,
        	fh=(-1.0),
        )
        self._amplitude_range = qtgui.Range(0, 1, 0.1, 0.2, 200)
        self._amplitude_win = qtgui.RangeWidget(self._amplitude_range, self.set_amplitude, "'amplitude'", "counter_slider", float, QtCore.Qt.Horizontal)
        self.top_layout.addWidget(self._amplitude_win)


        ##################################################
        # Connections
        ##################################################
        self.connect((self.analog_wfm_tx_0, 0), (self.rational_resampler_xxx_0, 0))
        self.connect((self.blocks_multiply_const_vxx_0, 0), (self.analog_wfm_tx_0, 0))
        self.connect((self.blocks_wavfile_source_0, 0), (self.blocks_multiply_const_vxx_0, 0))
        self.connect((self.rational_resampler_xxx_0, 0), (self.osmosdr_sink_0, 0))


    def closeEvent(self, event):
        self.settings = Qt.QSettings("GNU Radio", "FMtran")
        self.settings.setValue("geometry", self.saveGeometry())
        self.stop()
        self.wait()

        event.accept()

    def get_samp_rate(self):
        return self.samp_rate

    def set_samp_rate(self, samp_rate):
        self.samp_rate = samp_rate
        self.osmosdr_sink_0.set_sample_rate(self.samp_rate)

    def get_center_fr(self):
        return self.center_fr

    def set_center_fr(self, center_fr):
        self.center_fr = center_fr
        self.osmosdr_sink_0.set_center_freq(self.center_fr, 0)

    def get_audioRate(self):
        return self.audioRate

    def set_audioRate(self, audioRate):
        self.audioRate = audioRate

    def get_amplitude(self):
        return self.amplitude

    def set_amplitude(self, amplitude):
        self.amplitude = amplitude




def main(top_block_cls=FMtran, options=None):

    qapp = Qt.QApplication(sys.argv)

    tb = top_block_cls()

    tb.start()

    tb.show()

    def sig_handler(sig=None, frame=None):
        tb.stop()
        tb.wait()

        Qt.QApplication.quit()

    signal.signal(signal.SIGINT, sig_handler)
    signal.signal(signal.SIGTERM, sig_handler)

    timer = Qt.QTimer()
    timer.start(500)
    timer.timeout.connect(lambda: None)

    qapp.exec_()

if __name__ == '__main__':
    main()
