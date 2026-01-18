#!/usr/bin/env python
"""
Unit tests for the Electric Vehicle (EV) module.

Tests cover:
- ElectricVehicle class functionality (SOC tracking, charging, range calculations)
- EVManager multi-vehicle coordination
- Energy/range conversions
- Configuration validation
"""

import logging
import unittest
from datetime import datetime, timedelta

import numpy as np
import pandas as pd

from emhass.ev import ElectricVehicle, EVManager


class TestElectricVehicle(unittest.TestCase):
    """Test cases for the ElectricVehicle class."""

    def setUp(self):
        """Set up test fixtures."""
        self.logger = logging.getLogger('test')
        self.logger.setLevel(logging.DEBUG)
        
        self.ev = ElectricVehicle(
            ev_index=0,
            battery_capacity=77000,  # 77 kWh in Wh
            charging_efficiency=0.9,
            nominal_charging_power=4600,  # 4.6 kW
            minimum_charging_power=1380,  # 1.38 kW
            consumption_efficiency=0.15,  # kWh/km
            logger=self.logger
        )

    def test_initialization(self):
        """Test that EV initializes with correct parameters."""
        self.assertEqual(self.ev.ev_index, 0)
        self.assertEqual(self.ev.battery_capacity, 77000)
        self.assertEqual(self.ev.charging_efficiency, 0.9)
        self.assertEqual(self.ev.nominal_charging_power, 4600)
        self.assertEqual(self.ev.minimum_charging_power, 1380)
        self.assertEqual(self.ev.consumption_efficiency, 0.15)
        self.assertEqual(self.ev.soc, 0.5)  # Default initial SOC

    def test_soc_bounds(self):
        """Test that SOC is clamped between 0 and 1."""
        self.ev.set_soc(1.5)  # Try to set above 1
        self.assertEqual(self.ev.get_soc(), 1.0)
        
        self.ev.set_soc(-0.5)  # Try to set below 0
        self.assertEqual(self.ev.get_soc(), 0.0)
        
        self.ev.set_soc(0.75)  # Valid value
        self.assertEqual(self.ev.get_soc(), 0.75)

    def test_get_energy_level(self):
        """Test getting energy level in Wh."""
        self.ev.set_soc(0.5)
        energy_wh = self.ev.get_energy_level()
        expected = 77000 * 0.5  # 38500 Wh
        self.assertAlmostEqual(energy_wh, expected, places=2)
        
        self.ev.set_soc(1.0)
        energy_wh = self.ev.get_energy_level()
        self.assertAlmostEqual(energy_wh, 77000, places=2)

    def test_get_current_range(self):
        """Test range calculation in kilometers."""
        self.ev.set_soc(1.0)  # Fully charged
        range_km = self.ev.get_current_range()
        # 77 kWh / 0.15 kWh/km = 513.33 km
        expected = 77.0 / 0.15
        self.assertAlmostEqual(range_km, expected, places=1)
        
        self.ev.set_soc(0.5)  # Half charged
        range_km = self.ev.get_current_range()
        expected = 38.5 / 0.15
        self.assertAlmostEqual(range_km, expected, places=1)

    def test_km_to_energy(self):
        """Test distance to energy conversion."""
        distance_km = 100
        energy_wh = self.ev.km_to_energy(distance_km)
        expected = 100 * 0.15 * 1000  # 15000 Wh
        self.assertAlmostEqual(energy_wh, expected, places=2)
        
        distance_km = 0
        energy_wh = self.ev.km_to_energy(distance_km)
        self.assertEqual(energy_wh, 0.0)

    def test_energy_to_km(self):
        """Test energy to distance conversion."""
        energy_wh = 15000  # 15 kWh
        distance_km = self.ev.energy_to_km(energy_wh)
        expected = 15 / 0.15  # 100 km
        self.assertAlmostEqual(distance_km, expected, places=1)
        
        energy_wh = 0
        distance_km = self.ev.energy_to_km(energy_wh)
        self.assertEqual(distance_km, 0.0)

    def test_calculate_soc_delta(self):
        """Test SOC change calculation."""
        power_w = 4600  # Nominal power
        time_step_hours = 0.5  # 30 minutes
        
        soc_delta = self.ev.calculate_soc_delta(power_w, time_step_hours)
        
        # Energy added: 4600W * 0.5h * 0.9 efficiency = 2070 Wh
        # SOC increase: 2070 / 77000 = 0.0269
        expected_delta = (4600 * 0.5 * 0.9) / 77000
        self.assertAlmostEqual(soc_delta, expected_delta, places=4)

    def test_update_soc(self):
        """Test updating SOC with charging power."""
        self.ev.set_soc(0.5)  # Start at 50%
        power_w = 4600  # Charge at nominal power
        time_step_hours = 0.5  # 30 minutes
        
        new_soc = self.ev.update_soc(power_w, time_step_hours)
        
        # Energy added: 4600W * 0.5h * 0.9 efficiency = 2070 Wh
        # SOC increase: 2070 / 77000 = 0.0269
        # New SOC: 0.5 + 0.0269 = 0.5269
        expected_soc = 0.5 + (4600 * 0.5 * 0.9 / 77000)
        self.assertAlmostEqual(new_soc, expected_soc, places=4)
        self.assertAlmostEqual(self.ev.get_soc(), expected_soc, places=4)

    def test_update_soc_full_battery(self):
        """Test charging when battery is already full."""
        self.ev.set_soc(1.0)  # Full battery
        power_w = 4600
        time_step_hours = 0.5
        
        new_soc = self.ev.update_soc(power_w, time_step_hours)
        self.assertEqual(new_soc, 1.0)  # Should stay at 100%

    def test_update_soc_zero_power(self):
        """Test charging with zero power."""
        self.ev.set_soc(0.5)
        new_soc = self.ev.update_soc(0, 0.5)
        self.assertEqual(new_soc, 0.5)  # No change

    def test_set_availability(self):
        """Test setting vehicle availability."""
        self.ev.set_availability(True)
        self.assertTrue(self.ev.is_available)
        
        self.ev.set_availability(False)
        self.assertFalse(self.ev.is_available)

    def test_set_minimum_required_soc(self):
        """Test setting minimum required SOC."""
        self.ev.set_minimum_required_soc(0.3)
        self.assertEqual(self.ev.minimum_required_soc, 0.3)
        
        # Test clamping
        self.ev.set_minimum_required_soc(1.5)
        self.assertEqual(self.ev.minimum_required_soc, 1.0)
        
        self.ev.set_minimum_required_soc(-0.5)
        self.assertEqual(self.ev.minimum_required_soc, 0.0)

    def test_get_charging_power_bounds(self):
        """Test getting charging power bounds."""
        # When not available
        self.ev.set_availability(False)
        min_power, max_power = self.ev.get_charging_power_bounds()
        self.assertEqual(min_power, 0.0)
        self.assertEqual(max_power, 0.0)
        
        # When available
        self.ev.set_availability(True)
        min_power, max_power = self.ev.get_charging_power_bounds()
        self.assertEqual(min_power, 1380)
        self.assertEqual(max_power, 4600)

class TestEVManager(unittest.TestCase):
    """Test cases for the EVManager class."""

    def setUp(self):
        """Set up test fixtures with multiple vehicles."""
        self.logger = logging.getLogger('test')
        self.logger.setLevel(logging.DEBUG)
        
        self.plant_conf = {
            'ev_battery_capacity': [77000, 40000],
            'ev_charging_efficiency': [0.9, 0.85],
            'ev_nominal_charging_power': [4600, 3680],
            'ev_minimum_charging_power': [1380, 1150],
            'ev_consumption_efficiency': [0.15, 0.18]
        }
        
        self.optim_conf = {
            'number_of_ev_loads': 2
        }
        
        self.manager = EVManager(
            plant_conf=self.plant_conf,
            optim_conf=self.optim_conf,
            logger=self.logger
        )

    def test_initialization(self):
        """Test that manager initializes with correct number of vehicles."""
        self.assertEqual(len(self.manager.evs), 2)
        self.assertEqual(self.manager.evs[0].ev_index, 0)
        self.assertEqual(self.manager.evs[1].ev_index, 1)
        self.assertTrue(self.manager.is_enabled())

    def test_initialization_disabled(self):
        """Test initialization with EV disabled."""
        optim_conf = {'number_of_ev_loads': 0}
        manager = EVManager(
            plant_conf={},
            optim_conf=optim_conf,
            logger=self.logger
        )
        self.assertEqual(len(manager.evs), 0)
        self.assertFalse(manager.is_enabled())

    def test_get_ev(self):
        """Test getting specific EV by index."""
        ev0 = self.manager.get_ev(0)
        ev1 = self.manager.get_ev(1)
        
        self.assertIsNotNone(ev0)
        self.assertIsNotNone(ev1)
        self.assertEqual(ev0.ev_index, 0)
        self.assertEqual(ev1.ev_index, 1)
        
        # Invalid index
        ev_invalid = self.manager.get_ev(5)
        self.assertIsNone(ev_invalid)

    def test_set_availability_schedule(self):
        """Test setting availability schedule."""
        availability = [1, 1, 0, 0, 1]
        # Should not raise an error
        self.manager.set_availability_schedule(0, availability)

    def test_set_range_requirements(self):
        """Test setting range requirements."""
        ranges = [0, 100, 200, 150, 0]
        # Should not raise an error
        self.manager.set_range_requirements(0, ranges)

    def test_multi_vehicle_configuration(self):
        """Test that vehicles have different configurations."""
        ev0 = self.manager.get_ev(0)
        ev1 = self.manager.get_ev(1)
        
        # Check different capacities
        self.assertEqual(ev0.battery_capacity, 77000)
        self.assertEqual(ev1.battery_capacity, 40000)
        
        # Check different powers
        self.assertEqual(ev0.nominal_charging_power, 4600)
        self.assertEqual(ev1.nominal_charging_power, 3680)


class TestEVConversions(unittest.TestCase):
    """Test energy and range conversion functions."""

    def setUp(self):
        """Set up EV for conversion tests."""
        self.logger = logging.getLogger('test')
        self.logger.setLevel(logging.DEBUG)
        
        self.ev = ElectricVehicle(
            ev_index=0,
            battery_capacity=77000,
            charging_efficiency=0.9,
            nominal_charging_power=4600,
            minimum_charging_power=1380,
            consumption_efficiency=0.15,
            logger=self.logger
        )

    def test_km_to_energy_conversion(self):
        """Test distance to energy conversion."""
        test_cases = [
            (0, 0.0),
            (100, 15000.0),  # Wh
            (200, 30000.0),
            (513.33, 76999.5)  # Full battery range
        ]
        
        for km, expected_wh in test_cases:
            result = self.ev.km_to_energy(km)
            self.assertAlmostEqual(result, expected_wh, places=0)

    def test_energy_to_km_conversion(self):
        """Test energy to distance conversion."""
        test_cases = [
            (0.0, 0),
            (15000.0, 100),  # Wh to km
            (30000.0, 200),
            (77000.0, 513.33)  # Full battery
        ]
        
        for wh, expected_km in test_cases:
            result = self.ev.energy_to_km(wh)
            self.assertAlmostEqual(result, expected_km, places=1)

    def test_soc_to_range_conversion(self):
        """Test SOC to available range conversion."""
        test_cases = [
            (0.0, 0.0),
            (0.25, 128.33),
            (0.5, 256.67),
            (0.75, 385.0),
            (1.0, 513.33)
        ]
        
        for soc, expected_km in test_cases:
            self.ev.set_soc(soc)
            result = self.ev.get_current_range()
            self.assertAlmostEqual(result, expected_km, places=1)


class TestEVEdgeCases(unittest.TestCase):
    """Test edge cases and boundary conditions."""

    def setUp(self):
        """Set up logger for edge case testing."""
        self.logger = logging.getLogger('test')
        self.logger.setLevel(logging.DEBUG)

    def test_negative_charging_power(self):
        """Test handling of negative charging power."""
        ev = ElectricVehicle(
            ev_index=0,
            battery_capacity=77000,
            charging_efficiency=0.9,
            nominal_charging_power=4600,
            minimum_charging_power=1380,
            consumption_efficiency=0.15,
            logger=self.logger
        )
        ev.set_soc(0.5)
        
        # Negative power should decrease SOC (discharging)
        new_soc = ev.update_soc(-1000, 0.5)
        self.assertLess(new_soc, 0.5)

    def test_very_long_charging_time(self):
        """Test charging for extended period."""
        ev = ElectricVehicle(
            ev_index=0,
            battery_capacity=77000,
            charging_efficiency=0.9,
            nominal_charging_power=4600,
            minimum_charging_power=1380,
            consumption_efficiency=0.15,
            logger=self.logger
        )
        ev.set_soc(0.1)  # Nearly empty
        
        # Charge for 10 hours at full power
        # Energy: 4600W * 10h * 0.9 = 41400 Wh
        # SOC increase: 41400 / 77000 = 0.5377
        # Final SOC: 0.1 + 0.5377 = 0.6377
        new_soc = ev.update_soc(4600, 10.0)
        
        # Should increase significantly but might not reach 100%
        self.assertGreater(new_soc, 0.5)
        self.assertLessEqual(new_soc, 1.0)
        
        # Now test starting from very low SOC with longer charging
        ev.set_soc(0.05)
        # Charge for 20 hours - should definitely cap at 100%
        new_soc = ev.update_soc(4600, 20.0)
        self.assertEqual(new_soc, 1.0)

    def test_repr_methods(self):
        """Test string representation methods."""
        ev = ElectricVehicle(
            ev_index=0,
            battery_capacity=77000,
            charging_efficiency=0.9,
            nominal_charging_power=4600,
            minimum_charging_power=1380,
            consumption_efficiency=0.15,
            logger=self.logger
        )
        
        repr_str = repr(ev)
        self.assertIn("ElectricVehicle", repr_str)
        self.assertIn("index=0", repr_str)

    def test_manager_repr_disabled(self):
        """Test manager representation when disabled."""
        manager = EVManager(
            plant_conf={},
            optim_conf={'number_of_ev_loads': 0},
            logger=self.logger
        )
        
        repr_str = repr(manager)
        self.assertIn("disabled", repr_str.lower())

    def test_manager_repr_enabled(self):
        """Test manager representation when enabled."""
        manager = EVManager(
            plant_conf={
                'ev_battery_capacity': [77000],
                'ev_charging_efficiency': [0.9],
                'ev_nominal_charging_power': [4600],
                'ev_minimum_charging_power': [1380],
                'ev_consumption_efficiency': [0.15]
            },
            optim_conf={'number_of_ev_loads': 1},
            logger=self.logger
        )
        
        repr_str = repr(manager)
        self.assertIn("EVManager", repr_str)
        self.assertIn("1 EVs", repr_str)


if __name__ == '__main__':
    unittest.main()
