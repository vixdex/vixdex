'use client';
import React, { useEffect, useRef } from 'react';
import { createChart } from 'lightweight-charts';

const LineChart = ({ data }) => {
  const chartContainerRef = useRef(null);
  const chartRef = useRef(null);
  const seriesRef = useRef(null);

  useEffect(() => {
    if (!chartContainerRef.current) return;

    const chart = createChart(chartContainerRef.current, {
      width: chartContainerRef.current.clientWidth,
      height: chartContainerRef.current.clientHeight,
      layout: {
        background: { color: '#121418' },
        textColor: '#F7EFDE',
      },
      grid: {
        vertLines: { color: '#503A39' },
        horzLines: { color: '#503A39' },
      },
      timeScale: {
        borderColor: '#503A39',
        timeVisible: true,
        secondsVisible: false,
      },
      rightPriceScale: { borderColor: '#503A39' },
    });
    chartRef.current = chart;

    const lineSeries = chart.addLineSeries({
      color: '#3EAFA4',
      lineWidth: 2,
    });
    seriesRef.current = lineSeries;

    lineSeries.setData(data);
    chart.timeScale().fitContent();

    const handleResize = () => {
      chart.applyOptions({
        width: chartContainerRef.current?.clientWidth || 0,
      });
    };
    window.addEventListener('resize', handleResize);

    return () => {
      window.removeEventListener('resize', handleResize);
      chart.remove();
    };
  }, [data]);

  useEffect(() => {
    if (seriesRef.current && data.length > 0) {
      seriesRef.current.setData(data);
      chartRef.current?.timeScale().fitContent();
    }
  }, [data]);

  return <div ref={chartContainerRef} className="w-full h-full" />;
};

export default LineChart;
