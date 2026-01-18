#!/usr/bin/env python3
"""
Electric Vehicle (EV) management module for EMHASS-EV.

This module provides classes and functions for managing electric vehicle
charging optimization, including battery state tracking, charging power
constraints, and range calculations.
"""

from __future__ import annotations

import logging
from typing import TYPE_CHECKING

import numpy as np
import pandas as pd

if TYPE_CHECKING:
    pass


class ElectricVehicle:
    """
    Electric Vehicle class for managing EV state and charging optimization.
    
    This class handles:
    - Battery state of charge (SOC) tracking
    - Charging power constraints (min/max)
    - Energy consumption calculations
    - Range requirements management
    """
    
    def __init__(
        self,
        ev_index: int,
        battery_capacity: float,
        charging_efficiency: float,
        nominal_charging_power: float,
        minimum_charging_power: float,
        consumption_efficiency: float,
        logger: logging.Logger,
    ) -> None:
        """
        Initialize an Electric Vehicle instance.
        
        :param ev_index: Index identifier for this EV (0-based)
        :type ev_index: int
        :param battery_capacity: Battery capacity in Wh
        :type battery_capacity: float
        :param charging_efficiency: Charging efficiency (0-1), e.g., 0.9 for 90%
        :type charging_efficiency: float
        :param nominal_charging_power: Maximum charging power in W
        :type nominal_charging_power: float
        :param minimum_charging_power: Minimum charging power in W (when charging)
        :type minimum_charging_power: float
        :param consumption_efficiency: Energy consumption in kWh/km
        :type consumption_efficiency: float
        :param logger: Logger object for logging
        :type logger: logging.Logger
        """
        self.ev_index = ev_index
        self.battery_capacity = battery_capacity  # Wh
        self.charging_efficiency = charging_efficiency  # 0-1
        self.nominal_charging_power = nominal_charging_power  # W
        self.minimum_charging_power = minimum_charging_power  # W
        self.consumption_efficiency = consumption_efficiency  # kWh/km
        self.logger = logger
        
        # State variables
        self.soc = 0.5  # Initial SOC (0-1), default 50%
        self.is_available = False  # Whether EV is at home and available to charge
        self.minimum_required_soc = 0.2  # Minimum SOC requirement (0-1)
        
        self.logger.info(
            f"EV {ev_index} initialized: "
            f"Capacity={battery_capacity}Wh, "
            f"Max Power={nominal_charging_power}W, "
            f"Min Power={minimum_charging_power}W, "
            f"Efficiency={charging_efficiency}, "
            f"Consumption={consumption_efficiency}kWh/km"
        )
    
    def set_soc(self, soc: float) -> None:
        """
        Set the current state of charge.
        
        :param soc: State of charge (0-1)
        :type soc: float
        """
        if not 0 <= soc <= 1:
            self.logger.warning(
                f"EV {self.ev_index}: Invalid SOC {soc}, clamping to [0, 1]"
            )
            soc = max(0.0, min(1.0, soc))
        self.soc = soc
        self.logger.debug(f"EV {self.ev_index}: SOC set to {soc:.2%}")
    
    def get_soc(self) -> float:
        """
        Get the current state of charge.
        
        :return: Current SOC (0-1)
        :rtype: float
        """
        return self.soc
    
    def get_energy_level(self) -> float:
        """
        Get the current energy level in Wh.
        
        :return: Current energy in Wh
        :rtype: float
        """
        return self.soc * self.battery_capacity
    
    def set_availability(self, is_available: bool) -> None:
        """
        Set whether the EV is available for charging (at home).
        
        :param is_available: True if EV is at home and available
        :type is_available: bool
        """
        self.is_available = is_available
        self.logger.debug(
            f"EV {self.ev_index}: Availability set to {is_available}"
        )
    
    def set_minimum_required_soc(self, soc: float) -> None:
        """
        Set the minimum required SOC for this timestep.
        
        :param soc: Minimum required SOC (0-1)
        :type soc: float
        """
        if not 0 <= soc <= 1:
            self.logger.warning(
                f"EV {self.ev_index}: Invalid minimum SOC {soc}, clamping to [0, 1]"
            )
            soc = max(0.0, min(1.0, soc))
        self.minimum_required_soc = soc
        self.logger.debug(
            f"EV {self.ev_index}: Minimum required SOC set to {soc:.2%}"
        )
    
    def km_to_energy(self, distance_km: float) -> float:
        """
        Convert distance in km to required energy in Wh.
        
        :param distance_km: Distance in kilometers
        :type distance_km: float
        :return: Required energy in Wh
        :rtype: float
        """
        energy_kwh = distance_km * self.consumption_efficiency
        energy_wh = energy_kwh * 1000  # Convert kWh to Wh
        return energy_wh
    
    def energy_to_km(self, energy_wh: float) -> float:
        """
        Convert energy in Wh to available range in km.
        
        :param energy_wh: Energy in Wh
        :type energy_wh: float
        :return: Available range in km
        :rtype: float
        """
        energy_kwh = energy_wh / 1000  # Convert Wh to kWh
        range_km = energy_kwh / self.consumption_efficiency
        return range_km
    
    def get_current_range(self) -> float:
        """
        Get the current available range in km.
        
        :return: Available range in kilometers
        :rtype: float
        """
        return self.energy_to_km(self.get_energy_level())
    
    def calculate_soc_delta(self, charging_power: float, time_step: float) -> float:
        """
        Calculate the change in SOC given charging power and time step.
        
        :param charging_power: Charging power in W (positive for charging)
        :type charging_power: float
        :param time_step: Time step duration in hours
        :type time_step: float
        :return: Change in SOC (0-1)
        :rtype: float
        """
        # Energy charged in Wh
        energy_charged = charging_power * time_step * self.charging_efficiency
        # Convert to SOC delta
        soc_delta = energy_charged / self.battery_capacity
        return soc_delta
    
    def update_soc(self, charging_power: float, time_step: float) -> float:
        """
        Update the SOC based on charging power and return new SOC.
        
        :param charging_power: Charging power in W (positive for charging)
        :type charging_power: float
        :param time_step: Time step duration in hours
        :type time_step: float
        :return: New SOC after charging (0-1)
        :rtype: float
        """
        soc_delta = self.calculate_soc_delta(charging_power, time_step)
        new_soc = self.soc + soc_delta
        
        # Clamp to valid range
        new_soc = max(0.0, min(1.0, new_soc))
        
        self.set_soc(new_soc)
        return new_soc
    
    def get_charging_power_bounds(self) -> tuple[float, float]:
        """
        Get the valid charging power bounds for this EV.
        
        :return: Tuple of (minimum_power, maximum_power) in W
        :rtype: tuple[float, float]
        """
        if not self.is_available:
            return (0.0, 0.0)
        return (self.minimum_charging_power, self.nominal_charging_power)
    
    def __repr__(self) -> str:
        """String representation of the EV."""
        return (
            f"ElectricVehicle(index={self.ev_index}, "
            f"SOC={self.soc:.2%}, "
            f"Range={self.get_current_range():.1f}km, "
            f"Available={self.is_available})"
        )


class EVManager:
    """
    Manager class for handling multiple electric vehicles.
    
    This class coordinates multiple EV instances and provides
    utility functions for optimization integration.
    """
    
    def __init__(
        self,
        plant_conf: dict,
        optim_conf: dict,
        logger: logging.Logger,
    ) -> None:
        """
        Initialize the EV Manager.
        
        :param plant_conf: Plant configuration dictionary
        :type plant_conf: dict
        :param optim_conf: Optimization configuration dictionary
        :type optim_conf: dict
        :param logger: Logger object
        :type logger: logging.Logger
        """
        self.plant_conf = plant_conf
        self.optim_conf = optim_conf
        self.logger = logger
        
        self.num_evs = optim_conf.get("number_of_ev_loads", 0)
        self.evs: list[ElectricVehicle] = []
        
        if self.num_evs > 0:
            self._initialize_evs()
        else:
            self.logger.info("EV optimization disabled (number_of_ev_loads = 0)")
    
    def _initialize_evs(self) -> None:
        """Initialize all EV instances based on configuration."""
        self.logger.info(f"Initializing {self.num_evs} electric vehicle(s)")
        
        # Get configuration arrays
        battery_capacities = self.plant_conf.get("ev_battery_capacity", [])
        charging_efficiencies = self.plant_conf.get("ev_charging_efficiency", [])
        nominal_powers = self.plant_conf.get("ev_nominal_charging_power", [])
        minimum_powers = self.plant_conf.get("ev_minimum_charging_power", [])
        consumptions = self.plant_conf.get("ev_consumption_efficiency", [])
        
        # Validate configuration
        if not all([
            len(battery_capacities) >= self.num_evs,
            len(charging_efficiencies) >= self.num_evs,
            len(nominal_powers) >= self.num_evs,
            len(minimum_powers) >= self.num_evs,
            len(consumptions) >= self.num_evs,
        ]):
            self.logger.error(
                "EV configuration arrays are incomplete. "
                f"Required {self.num_evs} entries for each parameter."
            )
            raise ValueError("Incomplete EV configuration")
        
        # Create EV instances
        for i in range(self.num_evs):
            ev = ElectricVehicle(
                ev_index=i,
                battery_capacity=battery_capacities[i],
                charging_efficiency=charging_efficiencies[i],
                nominal_charging_power=nominal_powers[i],
                minimum_charging_power=minimum_powers[i],
                consumption_efficiency=consumptions[i],
                logger=self.logger,
            )
            self.evs.append(ev)
    
    def is_enabled(self) -> bool:
        """
        Check if EV optimization is enabled.
        
        :return: True if at least one EV is configured
        :rtype: bool
        """
        return self.num_evs > 0
    
    def get_ev(self, index: int) -> ElectricVehicle | None:
        """
        Get an EV instance by index.
        
        :param index: EV index (0-based)
        :type index: int
        :return: EV instance or None if index invalid
        :rtype: ElectricVehicle | None
        """
        if 0 <= index < len(self.evs):
            return self.evs[index]
        self.logger.warning(f"Invalid EV index: {index}")
        return None
    
    def set_availability_schedule(
        self,
        ev_index: int,
        availability_array: list[int] | np.ndarray | pd.Series,
    ) -> None:
        """
        Set the availability schedule for an EV.
        
        :param ev_index: Index of the EV
        :type ev_index: int
        :param availability_array: Array of 0 (not available) or 1 (available)
        :type availability_array: list or np.ndarray or pd.Series
        """
        ev = self.get_ev(ev_index)
        if ev is None:
            return
        
        self.logger.info(
            f"EV {ev_index}: Setting availability schedule "
            f"({len(availability_array)} timesteps)"
        )
        # Note: Actual availability will be set per timestep during optimization
    
    def set_range_requirements(
        self,
        ev_index: int,
        range_requirements_km: list[float] | np.ndarray | pd.Series,
    ) -> None:
        """
        Set the minimum range requirements for an EV.
        
        :param ev_index: Index of the EV
        :type ev_index: int
        :param range_requirements_km: Array of minimum range in km per timestep
        :type range_requirements_km: list or np.ndarray or pd.Series
        """
        ev = self.get_ev(ev_index)
        if ev is None:
            return
        
        self.logger.info(
            f"EV {ev_index}: Setting range requirements "
            f"({len(range_requirements_km)} timesteps)"
        )
        # Note: Requirements will be applied per timestep during optimization
    
    def __repr__(self) -> str:
        """String representation of the EV Manager."""
        if not self.is_enabled():
            return "EVManager(disabled)"
        return f"EVManager({self.num_evs} EVs: {self.evs})"
