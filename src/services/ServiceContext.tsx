import React, { createContext, useContext, useMemo } from 'react';
import { createServiceContainer, type ServiceContainer } from './index';

const ServiceContext = createContext<ServiceContainer | null>(null);

export const ServiceProvider: React.FC<{
  value?: ServiceContainer;
  children: React.ReactNode;
}> = ({ value, children }) => {
  const container = useMemo(() => value ?? createServiceContainer(), [value]);
  return <ServiceContext.Provider value={container}>{children}</ServiceContext.Provider>;
};

export const useServices = (): ServiceContainer => {
  const ctx = useContext(ServiceContext);
  if (!ctx) {
    throw new Error('useServices must be used inside <ServiceProvider>.');
  }
  return ctx;
};
